import Foundation
import Network

/// Original simulator, loopback only. Exercises the same sockets, decoder and output pipeline as hardware.
public final class LoopbackSimulator: @unchecked Sendable {
    private let queue = DispatchQueue(label:"VitaBridge.simulator")
    private var tcp: NWListener?, udp: NWListener?, timer: DispatchSourceTimer?
    private var clients: [UUID:NWConnection] = [:]
    private var streams: [UUID:(NWConnection,Double)] = [:]
    private var sequence: UInt32 = 0
    private var started = 0.0
    public init() {}
    public func start(onError: @escaping @Sendable (String) -> Void = { _ in }) {
        queue.async { [self] in
            do {
                started = ProcessInfo.processInfo.systemUptime
                func parameters(_ tcp: Bool, _ port: UInt16) -> NWParameters {
                    let p = tcp ? NWParameters.tcp : NWParameters.udp
                    p.requiredLocalEndpoint = .hostPort(host:"127.0.0.1",port:NWEndpoint.Port(rawValue:port)!)
                    p.allowLocalEndpointReuse = true; return p
                }
                let t = try NWListener(using:parameters(true,15000)); tcp = t
                t.stateUpdateHandler = { if case .failed(let e) = $0 { onError("Simulator TCP: \(e)") } }
                t.newConnectionHandler = { [weak self] c in
                    guard let self else { return }; let id = UUID(); self.clients[id] = c
                    c.start(queue:self.queue); self.readRequest(c,id:id,buffer:Data())
                }; t.start(queue:queue)
                let u = try NWListener(using:parameters(false,15001)); udp = u
                u.stateUpdateHandler = { if case .failed(let e) = $0 { onError("Simulator UDP: \(e)") } }
                u.newConnectionHandler = { [weak self] c in
                    guard let self else { return }; let id = UUID(); self.clients[id] = c
                    c.start(queue:self.queue); self.readHello(c,id:id)
                }; u.start(queue:queue)
                let timer = DispatchSource.makeTimerSource(queue:queue)
                timer.schedule(deadline:.now(),repeating:.milliseconds(5))
                timer.setEventHandler { [weak self] in self?.stream() }; timer.resume(); self.timer = timer
            } catch { onError("Simulator: \(error)") }
        }
    }
    public func stop() {
        queue.async { [self] in
            timer?.cancel(); timer = nil; tcp?.cancel(); udp?.cancel(); tcp = nil; udp = nil
            for c in clients.values { c.cancel() }; clients.removeAll(); streams.removeAll()
        }
    }
    private func readRequest(_ c: NWConnection, id: UUID, buffer: Data) {
        c.receive(minimumIncompleteLength:1,maximumLength:8-buffer.count) { [weak self] data,_,done,error in
            guard let self else { return }
            var b = buffer; if let data { b.append(data) }
            guard error == nil, !done else { self.clients.removeValue(forKey:id); c.cancel(); return }
            if b.count == 8 {
                guard b == Data([86,80,65,68,50,0,0,0]) else { c.cancel(); self.clients.removeValue(forKey:id); return }
                c.send(content:self.packet(),completion:.contentProcessed { [weak self] error in
                    if error == nil { self?.readRequest(c,id:id,buffer:Data()) }
                })
            } else { self.readRequest(c,id:id,buffer:b) }
        }
    }
    private func readHello(_ c: NWConnection, id: UUID) {
        c.receiveMessage { [weak self] data,_,_,error in
            guard let self else { return }
            if error != nil { self.streams.removeValue(forKey:id); self.clients.removeValue(forKey:id); return }
            if data == Data("VPAD_STREAM\0".utf8) { self.streams[id] = (c,ProcessInfo.processInfo.systemUptime) }
            self.readHello(c,id:id)
        }
    }
    private func stream() {
        sequence &+= 1
        var data = Data("VPS1".utf8); append(sequence,to:&data); data.append(packet())
        let now = ProcessInfo.processInfo.systemUptime
        for (_, pair) in streams where now-pair.1 < 3 { pair.0.send(content:data,completion:.idempotent) }
    }
    private func append<T: FixedWidthInteger>(_ number: T, to data: inout Data) {
        var n = number.littleEndian; withUnsafeBytes(of:&n) { data.append(contentsOf:$0) }
    }
    private func packet() -> Data {
        let t = ProcessInfo.processInfo.systemUptime-started
        let bits: [UInt32] = [1,8,16,32,64,128,256,512,4096,8192,16384,32768,65536]
        var b = Data(); append(bits[Int(t*2)%bits.count],to:&b)
        for a in [cos(t*2),sin(t*2),cos(-t*2),sin(-t*2)] { b.append(UInt8(clamping:Int(128+127*a))) }
        b.append(contentsOf:[1,1,0,0])
        for (x,y,id) in [(UInt16(960+800*sin(t)),UInt16(544),UInt8(1)),(UInt16(0),UInt16(0),UInt8(0)),(UInt16(960),UInt16(544+400*cos(t)),UInt8(2)),(UInt16(0),UInt16(0),UInt8(0))] {
            append(x,to:&b); append(y,to:&b); b.append(contentsOf:[id,0])
        }
        for f: Float in [Float(sin(t)*0.5),0,-1,0,Float(cos(t)*0.5),0] { append(f.bitPattern,to:&b) }
        append(UInt32(truncatingIfNeeded:UInt64(t*1_000_000)),to:&b); b.append(contentsOf:[80,0,0,0])
        return b
    }
}
