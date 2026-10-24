import Foundation
import Darwin
import Network
import VitaProtocol

public struct ConnectionSnapshot: Sendable {
    public var status = "Disconnected", host = "", mode = "Wi-Fi"
    public var state = ControllerState()
    public var packets: UInt64 = 0, malformed: UInt64 = 0, lost: UInt64 = 0, reordered: UInt64 = 0
    public var packetsPerSecond = 0.0, intervalMS = 0.0
    public var lastPacket: TimeInterval = 0
    public init() {}
}
public struct TransportPorts: Sendable {
    public let control: UInt16, stream: UInt16
    public init(control: UInt16, stream: UInt16) { self.control = control; self.stream = stream }
    public static let vita = TransportPorts(control:5000,stream:5001)
    public static let demo = TransportPorts(control:15000,stream:15001)
}
private enum LinkError: Error { case socket, timeout, closed, invalidAddress, invalidDiscovery }

/// One bounded worker owns all descriptors. Cancellation is observed within 50 ms during reads,
/// including partial TCP frames. No receive path enqueues input onto the main thread.
public final class VitaConnectionManager: @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot = ConnectionSnapshot()
    private var generation = UUID()
    private var reconnect = true
    private var callback: (@Sendable (ControllerState?) -> Void)?
    private let worker = DispatchQueue(label:"VitaBridge.transport", qos:.userInteractive)
    private let path = NWPathMonitor()
    public init(onInput: @escaping @Sendable (ControllerState?) -> Void) {
        callback = onInput
        path.start(queue:DispatchQueue(label:"VitaBridge.network-path"))
    }
    deinit { path.cancel() }
    public func read() -> ConnectionSnapshot { lock.withLock { snapshot } }
    public func setAutoReconnect(_ value: Bool) { lock.withLock { reconnect = value } }
    public func connect(host: String = "", ports: TransportPorts = .vita) {
        let token = UUID()
        lock.withLock { generation = token; snapshot = ConnectionSnapshot(); snapshot.status = host.isEmpty ? "Discovering…" : "Connecting…"; callback?(nil) }
        worker.async { [self] in run(host:host, ports:ports, token:token) }
    }
    public func disconnect() {
        lock.withLock { generation = UUID(); snapshot.status = "Disconnected"; snapshot.state = ControllerState(); snapshot.packetsPerSecond = 0; callback?(nil) }
    }
    private func active(_ token: UUID) -> Bool { lock.withLock { generation == token } }
    private func status(_ text: String, token: UUID) { lock.withLock { if generation == token { snapshot.status = text } } }
    private func pause(_ seconds: Double, token: UUID) {
        let end = now + seconds
        while active(token) && now < end { usleep(20_000) }
    }
    private var now: Double { ProcessInfo.processInfo.systemUptime }
    public static func isLocalIPv4(_ host: String) -> Bool {
        let p = host.split(separator:".").compactMap { UInt8($0) }
        guard p.count == 4, host.split(separator:".").count == 4 else { return false }
        return p[0] == 10 || p[0] == 127 || (p[0] == 192 && p[1] == 168) || (p[0] == 172 && (16...31).contains(p[1])) || (p[0] == 169 && p[1] == 254)
    }
    private func address(_ host: String, port: UInt16) throws -> sockaddr_in {
        guard Self.isLocalIPv4(host) else { throw LinkError.invalidAddress }
        var a = sockaddr_in(); a.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); a.sin_family = sa_family_t(AF_INET); a.sin_port = port.bigEndian
        guard inet_pton(AF_INET,host,&a.sin_addr) == 1 else { throw LinkError.invalidAddress }; return a
    }
    private func socketAddress<T>(_ a: inout sockaddr_in, _ body: (UnsafePointer<sockaddr>, socklen_t) throws -> T) rethrows -> T {
        try withUnsafePointer(to:&a) { try $0.withMemoryRebound(to:sockaddr.self, capacity:1) { try body($0,socklen_t(MemoryLayout<sockaddr_in>.size)) } }
    }
    private func makeSocket(_ type: Int32) throws -> Int32 {
        let fd = Darwin.socket(AF_INET,type,0); guard fd >= 0 else { throw LinkError.socket }
        var one: Int32 = 1
        setsockopt(fd,SOL_SOCKET,SO_NOSIGPIPE,&one,socklen_t(MemoryLayout<Int32>.size))
        _ = fcntl(fd,F_SETFL,O_NONBLOCK)
        return fd
    }
    private func wait(_ fd: Int32, events: Int16, until: Double, token: UUID) throws {
        while active(token) && now < until {
            var p = pollfd(fd:fd,events:events,revents:0)
            let ret = poll(&p,1,Int32(min(50,max(1,(until-now)*1000))))
            if ret > 0 {
                if p.revents & events != 0 { return }
                if p.revents & Int16(POLLERR | POLLHUP | POLLNVAL) != 0 { throw LinkError.closed }
            } else if ret < 0 && errno != EINTR { throw LinkError.socket }
        }
        throw LinkError.timeout
    }
    private func sendAll(_ data: Data, fd: Int32, token: UUID) throws {
        let deadline = now+1
        try data.withUnsafeBytes { raw in
            var offset = 0
            while offset < data.count {
                try wait(fd,events:Int16(POLLOUT),until:deadline,token:token)
                let n = send(fd,raw.baseAddress!.advanced(by:offset),data.count-offset,0)
                if n > 0 { offset += n } else if errno != EAGAIN && errno != EINTR { throw LinkError.closed }
            }
        }
    }
    private func receivePacket(fd: Int32, token: UUID) throws -> Data {
        var bytes = [UInt8](repeating:0,count:68), count = 0
        let deadline = now+1
        do {
            while count < 68 {
                try wait(fd,events:Int16(POLLIN),until:deadline,token:token)
                let n = bytes.withUnsafeMutableBytes { recv(fd,$0.baseAddress!.advanced(by:count),68-count,0) }
                if n > 0 { count += n }
                else if n == 0 { throw LinkError.closed }
                else if errno != EAGAIN && errno != EINTR { throw LinkError.socket }
            }
        } catch {
            if count == 16 { throw ProtocolError.legacy }
            throw error
        }
        return Data(bytes)
    }
    public static func validDiscovery(_ data: Data) -> Bool { data == Data("VITAPAD_HERE".utf8) }
    private func discover(ports: TransportPorts, token: UUID) throws -> String {
        let fd = try makeSocket(SOCK_DGRAM); defer { close(fd) }
        var one: Int32 = 1; setsockopt(fd,SOL_SOCKET,SO_BROADCAST,&one,4)
        var targets = ["255.255.255.255","127.0.0.1"]
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&interfaces) == 0 {
            var cursor = interfaces
            while let i = cursor {
                if let a = i.pointee.ifa_dstaddr, a.pointee.sa_family == UInt8(AF_INET), i.pointee.ifa_flags & UInt32(IFF_BROADCAST) != 0 {
                    let ip = a.withMemoryRebound(to:sockaddr_in.self, capacity:1) { inet_ntoa($0.pointee.sin_addr).map { String(cString:$0) } }
                    if let ip { targets.append(ip) }
                }; cursor = i.pointee.ifa_next
            }
            freeifaddrs(interfaces)
        }
        for ip in Set(targets) {
            var a = sockaddr_in(); a.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); a.sin_family = sa_family_t(AF_INET); a.sin_port = ports.control.bigEndian
            inet_pton(AF_INET,ip,&a.sin_addr)
            let request = Array("VITAPAD_DISCOVER".utf8)
            _ = socketAddress(&a) { ptr,len in request.withUnsafeBytes { sendto(fd,$0.baseAddress,$0.count,0,ptr,len) } }
        }
        let deadline = now+1.5
        while now < deadline {
            try wait(fd,events:Int16(POLLIN),until:deadline,token:token)
            var b = [UInt8](repeating:0,count:128), sender = sockaddr_in(), length = socklen_t(MemoryLayout<sockaddr_in>.size)
            let count = withUnsafeMutablePointer(to:&sender) { ptr in ptr.withMemoryRebound(to:sockaddr.self,capacity:1) { recvfrom(fd,&b,b.count,0,$0,&length) } }
            if count > 0, Self.validDiscovery(Data(b.prefix(count))), sender.sin_port == ports.control.bigEndian,
               let ip = inet_ntoa(sender.sin_addr).map({String(cString:$0)}), Self.isLocalIPv4(ip) { return ip }
        }
        throw LinkError.invalidDiscovery
    }
    private func run(host: String, ports: TransportPorts, token: UUID) {
        var target = host
        while active(token) {
            do {
                if target.isEmpty { status("Discovering…",token:token); target = try discover(ports:ports,token:token) }
                try session(host:target,ports:ports,token:token)
            } catch {
                guard active(token) else { return }
                lock.withLock {
                    if generation == token { callback?(nil); snapshot.state = ControllerState(); snapshot.packetsPerSecond = 0 }
                }
                if case ProtocolError.legacy = error { status("Unsupported legacy VitaPad: install VitaPad-NG V2",token:token); return }
                if case LinkError.invalidAddress = error { status("Enter a private/local IPv4 address",token:token); return }
                status("Connection lost / unavailable (\(error)) · retrying",token:token)
            }
            guard active(token), lock.withLock({reconnect}) else { return }
            pause(0.5,token:token)
            // A manually selected device is never silently replaced with another discovery responder.
            if host.isEmpty { target = "" }
        }
    }
    private func session(host: String, ports: TransportPorts, token: UUID) throws {
        let tcp = try makeSocket(SOCK_STREAM); defer { close(tcp) }
        var a = try address(host,port:ports.control)
        let result = socketAddress(&a) { Darwin.connect(tcp,$0,$1) }
        guard result == 0 || errno == EINPROGRESS else { throw LinkError.socket }
        try wait(tcp,events:Int16(POLLOUT),until:now+2,token:token)
        var error: Int32 = 0, length = socklen_t(4)
        getsockopt(tcp,SOL_SOCKET,SO_ERROR,&error,&length); guard error == 0 else { throw LinkError.socket }
        var one: Int32 = 1; setsockopt(tcp,IPPROTO_TCP,TCP_NODELAY,&one,4)
        lock.withLock { if generation == token { snapshot.host = host; snapshot.status = "Connected · probing UDP" } }
        try sendAll(PadDecoder.request,fd:tcp,token:token)
        let initial = try PadDecoder.decode(receivePacket(fd:tcp,token:token))
        var stats = SequenceTracker(), last = now, window = now, windowPackets = 0.0
        func accept(_ s: ControllerState) {
            guard active(token) else { return }
            let time = now, interval = (time-last)*1000; last = time; windowPackets += 1
            lock.withLock {
                guard generation == token else { return }
                snapshot.state = s; snapshot.packets += 1; snapshot.intervalMS = interval; snapshot.lastPacket = time
                snapshot.lost = stats.lost; snapshot.reordered = stats.reordered
                if time-window >= 0.5 { snapshot.packetsPerSecond = windowPackets/(time-window); windowPackets = 0; window = time }
                callback?(s)
            }
        }
        accept(initial)
        let udp = try makeSocket(SOCK_DGRAM); defer { close(udp) }
        var ua = try address(host,port:ports.stream)
        guard socketAddress(&ua,{Darwin.connect(udp,$0,$1)}) == 0 else { throw LinkError.socket }
        let start = now
        var lastHello = 0.0, heartbeat = now, streaming = false, polling = false
        var buffer = [UInt8](repeating:0,count:512)
        while active(token) {
            let time = now
            if time-lastHello >= 0.25 {
                PadDecoder.hello.withUnsafeBytes { _ = send(udp,$0.baseAddress,$0.count,0) }; lastHello = time
            }
            if !streaming && time-start >= 1 { polling = true; status("Connected · TCP polling",token:token) }
            if streaming && time-last > 1 { throw LinkError.timeout }
            if (polling || time-heartbeat >= 0.25) {
                try sendAll(PadDecoder.request,fd:tcp,token:token)
                let s = try PadDecoder.decode(receivePacket(fd:tcp,token:token)); heartbeat = now
                if polling { accept(s) }
            }
            var p = pollfd(fd:udp,events:Int16(POLLIN),revents:0)
            _ = poll(&p,1,polling ? 2 : 10)
            if p.revents & Int16(POLLERR) != 0 { _ = recv(udp,&buffer,buffer.count,0); usleep(2_000) }
            if p.revents & Int16(POLLIN) != 0 {
                // Bounded per-iteration drain prevents hostile senders from starving heartbeat/cancellation.
                for _ in 0..<64 {
                    let n = recv(udp,&buffer,buffer.count,0); if n <= 0 { break }
                    do {
                        let s = try PadDecoder.decode(Data(buffer.prefix(n)),stream:true)
                        try stats.accept(s.sequence!)
                        if !streaming { streaming = true; polling = false; status("Connected · UDP streaming",token:token) }
                        accept(s)
                    } catch {
                        lock.withLock {
                            if generation == token {
                                snapshot.lost = stats.lost; snapshot.reordered = stats.reordered
                                if error as? ProtocolError != .outOfOrder { snapshot.malformed += 1 }
                            }
                        }
                    }
                }
            }
        }
    }
}
