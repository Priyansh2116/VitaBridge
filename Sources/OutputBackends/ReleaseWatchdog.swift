import Foundation
import Darwin
import CoreGraphics
import ControllerEngine

/// Records only VitaBridge-owned holds. The helper never emits a key-down or mouse-down.
public struct WatchdogLedger {
    private var keys: Set<UInt16> = [], buttons: Set<Int> = []
    public init() {}
    public mutating func consume(_ line: String) {
        let p = line.split(separator:" ")
        guard p.count == 3, let code = Int(p[1]), p[2] == "0" || p[2] == "1" else { return }
        if p[0] == "k", (0...127).contains(code) {
            if p[2] == "1" { keys.insert(UInt16(code)) } else { keys.remove(UInt16(code)) }
        } else if p[0] == "m", (0...2).contains(code) {
            if p[2] == "1" { buttons.insert(code) } else { buttons.remove(code) }
        }
    }
    public mutating func release() -> [OutputEvent] {
        let events = keys.sorted().map { OutputEvent.key($0,false) } + buttons.sorted().map { OutputEvent.mouseButton($0,false) }
        keys.removeAll(); buttons.removeAll(); return events
    }
}
final class ReleaseWatchdogClient {
    private let process = Process(), pipe = Pipe()
    private var lastHeartbeat = 0.0
    var running: Bool { process.isRunning }
    init?() {
        guard let executable = Bundle.main.executableURL,
              executable.lastPathComponent == "VitaBridge" else { return nil }
        process.executableURL = executable; process.arguments = ["--release-watchdog"]
        process.standardInput = pipe; process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
        do { try process.run() } catch { return nil }
        _ = fcntl(pipe.fileHandleForWriting.fileDescriptor,F_SETNOSIGPIPE,1)
        _ = fcntl(pipe.fileHandleForWriting.fileDescriptor,F_SETFL,O_NONBLOCK)
    }
    func track(_ type: String, _ code: Int, _ down: Bool) -> Bool { write("\(type) \(code) \(down ? 1 : 0)\n") }
    func heartbeat() {
        let now = ProcessInfo.processInfo.systemUptime
        if now-lastHeartbeat >= 0.1 { _ = write("p\n"); lastHeartbeat = now }
    }
    private func write(_ text: String) -> Bool {
        guard process.isRunning else { return false }
        let bytes = Array(text.utf8)
        return bytes.withUnsafeBytes { Darwin.write(pipe.fileHandleForWriting.fileDescriptor,$0.baseAddress,$0.count) == $0.count }
    }
    deinit { try? pipe.fileHandleForWriting.close() } // EOF causes release even after parent crash.
}
public enum ReleaseWatchdog {
    /// Runs before AppKit initialization when the same executable is launched as a child helper.
    public static func run(auditOnly: Bool = false) {
        var ledger = WatchdogLedger(), buffered = Data(), lastRead = ProcessInfo.processInfo.systemUptime
        let source = CGEventSource(stateID:.hidSystemState)
        func release(_ events: [OutputEvent]) {
            for event in events {
                if auditOnly { print(String(describing:event)); continue }
                switch event {
                case let .key(code,_):
                    let e = CGEvent(keyboardEventSource:source,virtualKey:code,keyDown:false); e?.flags = []; e?.post(tap:.cghidEventTap)
                case let .mouseButton(code,_):
                    let type: CGEventType = code == 0 ? .leftMouseUp : code == 1 ? .rightMouseUp : .otherMouseUp
                    let e = CGEvent(mouseEventSource:source,mouseType:type,mouseCursorPosition:CGEvent(source:source)?.location ?? .zero,mouseButton:CGMouseButton(rawValue:UInt32(code))!)
                    e?.flags = []; e?.post(tap:.cghidEventTap)
                default: break
                }
            }
        }
        while true {
            var p = pollfd(fd:STDIN_FILENO,events:Int16(POLLIN),revents:0)
            let result = poll(&p,1,100)
            if result > 0 {
                var bytes = [UInt8](repeating:0,count:1024)
                let count = Darwin.read(STDIN_FILENO,&bytes,bytes.count)
                if count <= 0 { release(ledger.release()); return }
                lastRead = ProcessInfo.processInfo.systemUptime; buffered.append(contentsOf:bytes.prefix(count))
                while let i = buffered.firstIndex(of:10) {
                    ledger.consume(String(decoding:buffered[..<i],as:UTF8.self)); buffered.removeSubrange(...i)
                }
                if buffered.count > 4096 { release(ledger.release()); return }
            }
            if ProcessInfo.processInfo.systemUptime-lastRead > 0.6 {
                release(ledger.release()); return // Parent hung or stopped sending heartbeats.
            }
        }
    }
}
