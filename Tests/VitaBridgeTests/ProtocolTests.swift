import XCTest
import Foundation
@testable import VitaProtocol
@testable import ControllerEngine
@testable import VitaTransport
@testable import OutputBackends

final class ProtocolTests: XCTestCase {
    func fixture(buttons: UInt32 = 0, stream: Bool = false, seq: UInt32 = 1) -> Data {
        var b = [UInt8](repeating:0,count:68)
        for i in 0..<4 { b[i] = UInt8(truncatingIfNeeded:buttons >> (8*i)) }
        b[4] = 0; b[5] = 128; b[6] = 255; b[7] = 128; b[64] = 80
        if stream { return Data(Array("VPS1".utf8) + (0..<4).map { UInt8(truncatingIfNeeded:seq >> (8*$0)) } + b) }
        return Data(b)
    }
    func testAnalogAndSimultaneousButtons() throws {
        let s = try PadDecoder.decode(fixture(buttons:VitaButton.cross.rawValue | VitaButton.l.rawValue))
        XCTAssertEqual(s.left.x,-1); XCTAssertEqual(s.right.x,1); XCTAssertEqual(s.left.y,0)
        XCTAssertTrue(s.pressed(.cross)); XCTAssertTrue(s.pressed(.l)); XCTAssertFalse(s.pressed(.circle)); XCTAssertEqual(s.battery,80)
    }
    func testTouchAndMotion() throws {
        var b = fixture(); b[8] = 2; b[9] = 1; b[12] = 100; b[14] = 90; b[16] = 7; b[18] = 200; b[30] = 40
        let s = try PadDecoder.decode(b)
        XCTAssertEqual(s.front.count,2); XCTAssertEqual(s.rear.count,1); XCTAssertEqual(s.front[0].id,7); XCTAssertEqual(s.front[1].x,200)
        XCTAssertEqual(s.accel,[0,0,0]); XCTAssertEqual(s.gyro,[0,0,0])
    }
    func testMalformedPackets() {
        for n in [0,1,15,16,67,69,75,77,512] { XCTAssertThrowsError(try PadDecoder.decode(Data(repeating:0,count:n))) }
        var b = fixture(); b[8] = 3; XCTAssertThrowsError(try PadDecoder.decode(b))
        b = fixture(); b[8] = 1; b[12] = 255; b[13] = 255; XCTAssertThrowsError(try PadDecoder.decode(b))
        b = fixture(); b[64] = 101; XCTAssertThrowsError(try PadDecoder.decode(b))
        b = fixture(); b[38] = 128; b[39] = 127; XCTAssertThrowsError(try PadDecoder.decode(b)) // +infinity float
        b = fixture(stream:true); b[0] = 0; XCTAssertThrowsError(try PadDecoder.decode(b,stream:true))
    }
    func testSequenceLossReorderingWrap() throws {
        var tracker = SequenceTracker(); try tracker.accept(UInt32.max-1); try tracker.accept(1)
        XCTAssertEqual(tracker.lost,2); XCTAssertThrowsError(try tracker.accept(0)); XCTAssertThrowsError(try tracker.accept(1)); XCTAssertEqual(tracker.reordered,2)
        try tracker.accept(2); XCTAssertEqual(tracker.last,2)
    }
    func testStreamDecoderAndUnknownBattery() throws {
        var b = fixture(stream:true,seq:123); b[72] = 255
        let s = try PadDecoder.decode(b,stream:true); XCTAssertEqual(s.sequence,123); XCTAssertNil(s.battery)
        XCTAssertEqual(PadDecoder.request,Data("VPAD2\0\0\0".utf8)); XCTAssertEqual(PadDecoder.hello.count,12)
    }
    func testDiscoveryAndLocalAddressValidation() {
        XCTAssertTrue(VitaConnectionManager.validDiscovery(Data("VITAPAD_HERE".utf8)))
        XCTAssertFalse(VitaConnectionManager.validDiscovery(Data("VITAPAD_HEREX".utf8)))
        for ip in ["127.0.0.1","192.168.1.10","172.31.0.2","10.0.0.4","169.254.2.1"] { XCTAssertTrue(VitaConnectionManager.isLocalIPv4(ip)) }
        for ip in ["8.8.8.8","192.168.1.999","localhost","127.0.1","172.32.1.1","192.168.1.1.x"] { XCTAssertFalse(VitaConnectionManager.isLocalIPv4(ip)) }
    }
}
final class MappingTests: XCTestCase {
    func testTransitionsAndNoStuckKeys() {
        let e = InputMappingEngine(), p = GameProfile.defaults[1]
        var s = ControllerState(); s.buttons = VitaButton.cross.rawValue
        XCTAssertEqual(e.update(s,profile:p),[.key(49,true)])
        XCTAssertEqual(e.update(s,profile:p),[])
        XCTAssertEqual(e.reset(),[.key(49,false)]); XCTAssertEqual(e.reset(),[])
    }
    func testSharedKeysAndCombinations() {
        let e = InputMappingEngine(); var p = GameProfile(name:"Test"); p.left = .disabled; p.right = .disabled
        p.bindings[String(VitaButton.cross.rawValue)] = InputBinding(keys:[0,55])
        p.bindings[String(VitaButton.circle.rawValue)] = InputBinding(keys:[0])
        var s = ControllerState(); s.buttons = VitaButton.cross.rawValue | VitaButton.circle.rawValue
        XCTAssertEqual(e.update(s,profile:p),[.key(55,true),.key(0,true)])
        s.buttons = VitaButton.circle.rawValue
        XCTAssertEqual(e.update(s,profile:p),[.key(55,false)])
        XCTAssertEqual(e.reset(),[.key(0,false)])
    }
    func testMouseAndAnalogCalibration() {
        let e = InputMappingEngine(); var p = GameProfile.defaults[2]
        p.rightCalibration.invertX = true
        var s = ControllerState(); s.buttons = VitaButton.r.rawValue; s.right.x = 1
        XCTAssertEqual(e.update(s,profile:p),[.mouseButton(0,true)])
        XCTAssertEqual(e.tick(seconds:0.01),[.move(-9,0)])
        XCTAssertEqual(e.reset(),[.mouseButton(0,false)]); XCTAssertEqual(e.tick(seconds:0.01),[])
        XCTAssertEqual(Calibration().apply(Stick(x:0.1,y:0),deadZone:0.2,sensitivity:1),Stick())
    }
    func testRapidInputAndStickAssignment() {
        let e = InputMappingEngine(), p = GameProfile.defaults[1]
        for _ in 0..<1000 {
            var s = ControllerState(); s.buttons = VitaButton.cross.rawValue; s.left.y = -1
            XCTAssertEqual(Set(e.update(s,profile:p).map(String.init(describing:))),Set([OutputEvent.key(49,true),.key(13,true)].map(String.init(describing:))))
            XCTAssertEqual(e.update(ControllerState(),profile:p).count,2)
        }
        XCTAssertTrue(e.reset().isEmpty)
    }
    func testTouchMapping() throws {
        let decoder = ProtocolTests(); var data = decoder.fixture(); data[8] = 1
        let s = try PadDecoder.decode(data); let e = InputMappingEngine(); var p = GameProfile(name:"Touch"); p.left = .disabled; p.right = .disabled
        p.bindings["frontTouch"] = InputBinding(mouse:1)
        XCTAssertEqual(e.update(s,profile:p),[.mouseButton(1,true)]); XCTAssertEqual(e.reset(),[.mouseButton(1,false)])
    }
    func testProfileRoundTripAndInvalidData() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("profiles.json")
        defer { try? FileManager.default.removeItem(at:url.deletingLastPathComponent()) }
        let profiles = GameProfile.defaults; try ProfileStore.save(profiles,to:url)
        XCTAssertEqual(try ProfileStore.load(url),profiles)
        var p = profiles[0]; p.deadZone = 1; XCTAssertThrowsError(try p.validated())
        p = profiles[0]; p.version = 2; XCTAssertThrowsError(try p.validated())
        p = profiles[0]; p.bindings["1"] = InputBinding(keys:[300]); XCTAssertThrowsError(try p.validated())
        try Data("{}".utf8).write(to:url); XCTAssertThrowsError(try ProfileStore.load(url))
    }
    func testIndependentBackends() {
        let monitor: any ControllerOutputBackend = MonitorOnlyOutput(), usb: any ControllerOutputBackend = NativeUSBPassthroughOutput()
        XCTAssertEqual(monitor.mode,.monitor); XCTAssertEqual(usb.mode,.nativeUSB)
        monitor.send([.key(0,true)]); monitor.reset(); usb.send([.key(0,true)]); usb.reset()
        XCTAssertFalse(VirtualHIDOutput.blocker.isEmpty)
    }
}

final class WatchdogTests: XCTestCase {
    func testCrashLedgerReleasesOnlyOwnedHolds() {
        var ledger = WatchdogLedger()
        ledger.consume("k 49 1"); ledger.consume("k 55 1"); ledger.consume("m 0 1")
        ledger.consume("k 49 0"); ledger.consume("p")
        XCTAssertEqual(ledger.release(),[.key(55,false),.mouseButton(0,false)])
        XCTAssertEqual(ledger.release(),[])
    }
    func testMalformedWatchdogCommandsCannotInject() {
        var ledger = WatchdogLedger()
        for line in ["k 999 1","m 3 1","k -1 1","k 49 4","garbage","k 1","m 0 1 trailing"] { ledger.consume(line) }
        XCTAssertEqual(ledger.release(),[])
    }
}
