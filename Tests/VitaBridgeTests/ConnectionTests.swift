import XCTest
import Foundation
import VitaProtocol
import VitaTransport
import ControllerEngine

private final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0, resets = 0
    private let engine = InputMappingEngine()
    private var keys: Set<UInt16> = []
    func receive(_ state: ControllerState?) {
        lock.withLock {
            let events: [OutputEvent]
            if let state { count += 1; events = engine.update(state,profile:GameProfile.defaults[1]) }
            else { resets += 1; events = engine.reset() }
            for e in events { if case let .key(key,down) = e { if down { keys.insert(key) } else { keys.remove(key) } } }
        }
    }
    var values: (Int,Int,Set<UInt16>) { lock.withLock { (count,resets,keys) } }
}
final class ConnectionTests: XCTestCase {
    private func eventually(_ seconds: Double = 5, _ predicate: () -> Bool) -> Bool {
        let deadline = ProcessInfo.processInfo.systemUptime+seconds
        while ProcessInfo.processInfo.systemUptime < deadline { if predicate() { return true }; Thread.sleep(forTimeInterval:0.02) }
        return predicate()
    }
    func testLoopbackDemoRealNetworkPipeline() {
        let server = LoopbackSimulator(); server.start { print($0) }
        let recorder = Recorder(), manager = VitaConnectionManager { _ in }
        let receiving = VitaConnectionManager { recorder.receive($0) }
        defer { receiving.disconnect(); manager.disconnect(); server.stop(); Thread.sleep(forTimeInterval:0.15) }
        receiving.connect(host:"127.0.0.1",ports:.demo)
        XCTAssertTrue(eventually { receiving.read().packets > 50 },receiving.read().status)
        let snapshot = receiving.read()
        XCTAssertTrue(snapshot.status.contains("UDP")); XCTAssertNotNil(snapshot.state.sequence)
        XCTAssertEqual(snapshot.state.battery,80); XCTAssertEqual(snapshot.state.front.count,1)
        receiving.disconnect()
        XCTAssertTrue(eventually { recorder.values.2.isEmpty })
        let n = recorder.values.0; Thread.sleep(forTimeInterval:0.15)
        XCTAssertEqual(recorder.values.0,n,"No stale worker delivery after disconnect")
    }
    private func fake(_ args: [String] = []) throws -> Process {
        guard let script = ProcessInfo.processInfo.environment["VITABRIDGE_FAKE_VITA"] else { throw XCTSkip("Set VITABRIDGE_FAKE_VITA to the separately fetched upstream tools/fake_vita.py") }
        let p = Process(); p.executableURL = URL(fileURLWithPath:"/usr/bin/env"); p.arguments = ["python3","-c", "import sys; p=sys.argv[1]; sys.argv=sys.argv[1:]; g={'__name__':'vitabridge_upstream_test','__file__':p}; exec(compile(open(p).read(),p,'exec'),g); g['PORT']=15000; g['STREAM_PORT']=15001; g['main']()",script] + args
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run(); Thread.sleep(forTimeInterval:0.2)
        XCTAssertTrue(p.isRunning,"Simulator failed to bind; stop any other simulator")
        return p
    }
    private func stop(_ process: Process) { if process.isRunning { process.terminate(); process.waitUntilExit() }; Thread.sleep(forTimeInterval:0.15) }
    func testUpstreamDiscovery() throws {
        let p = try fake(); defer { stop(p) }
        let m = VitaConnectionManager { _ in }; defer { m.disconnect() }
        m.connect(ports:.demo)
        XCTAssertTrue(eventually { m.read().packets > 50 },m.read().status)
        XCTAssertTrue(m.read().status.contains("UDP")); XCTAssertEqual(m.read().state.battery,80)
    }
    func testUpstreamManualConnectionWithoutDiscovery() throws {
        let p = try fake(["--no-discovery"]); defer { stop(p) }
        let m = VitaConnectionManager { _ in }; defer { m.disconnect() }
        m.connect(host:"127.0.0.1",ports:.demo); XCTAssertTrue(eventually { m.read().packets > 30 },m.read().status)
    }
    func testUpstreamLegacyVersionRejected() throws {
        let p = try fake(["--legacy"]); defer { stop(p) }
        let m = VitaConnectionManager { _ in }; defer { m.disconnect() }
        m.connect(host:"127.0.0.1",ports:.demo)
        XCTAssertTrue(eventually { m.read().status.contains("Unsupported legacy") },m.read().status)
        XCTAssertEqual(m.read().packets,0)
    }
    func testUpstreamPollingFallback() throws {
        let p = try fake(["--no-stream"]); defer { stop(p) }
        let m = VitaConnectionManager { _ in }; defer { m.disconnect() }
        m.connect(host:"127.0.0.1",ports:.demo)
        XCTAssertTrue(eventually { m.read().packets > 20 && m.read().status.contains("TCP polling") },m.read().status)
        XCTAssertNil(m.read().state.sequence)
    }
    func testUpstreamPacketLoss() throws {
        let p = try fake(["--stream-loss","0.35"]); defer { stop(p) }
        let m = VitaConnectionManager { _ in }; defer { m.disconnect() }
        m.connect(host:"127.0.0.1",ports:.demo)
        XCTAssertTrue(eventually { m.read().lost > 5 && m.read().packets > 30 },m.read().status)
        XCTAssertEqual(m.read().malformed,0)
    }
    func testUpstreamDisconnectReconnectAndRelease() throws {
        let p = try fake(["--drop-every","1.5"]); defer { stop(p) }
        let recorder = Recorder(), m = VitaConnectionManager { recorder.receive($0) }; defer { m.disconnect() }
        m.connect(host:"127.0.0.1",ports:.demo)
        XCTAssertTrue(eventually { recorder.values.0 > 30 })
        let initial = recorder.values
        XCTAssertTrue(eventually(6) { recorder.values.1 > initial.1 && recorder.values.0 > initial.0+100 },m.read().status)
        m.disconnect(); XCTAssertTrue(recorder.values.2.isEmpty)
    }
    func testUpstreamSuddenExitNeutralizes() throws {
        let p = try fake(); let recorder = Recorder(), m = VitaConnectionManager { recorder.receive($0) }
        defer { m.disconnect(); stop(p) }
        m.setAutoReconnect(false); m.connect(host:"127.0.0.1",ports:.demo)
        XCTAssertTrue(eventually { !recorder.values.2.isEmpty })
        stop(p)
        XCTAssertTrue(eventually(3) { recorder.values.2.isEmpty && m.read().state.buttons == 0 })
    }
}
