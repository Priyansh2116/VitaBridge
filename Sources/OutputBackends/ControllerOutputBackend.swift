import Foundation
import CoreGraphics
@preconcurrency import ApplicationServices
import VitaProtocol
import ControllerEngine

public enum OutputMode: String, CaseIterable, Codable, Sendable { case monitor = "Monitor Only", keyboardMouse = "Keyboard / Mouse", nativeUSB = "Native USB Passthrough", virtualHID = "Virtual Gamepad (Unavailable)" }
public protocol ControllerOutputBackend: AnyObject {
    var mode: OutputMode { get }
    func send(_ events: [OutputEvent])
    func reset()
}
public final class MonitorOnlyOutput: ControllerOutputBackend {
    public let mode: OutputMode = .monitor
    public init() {}
    public func send(_ events: [OutputEvent]) {}
    public func reset() {}
}
public final class NativeUSBPassthroughOutput: ControllerOutputBackend {
    public let mode: OutputMode = .nativeUSB
    public init() {}
    public func send(_ events: [OutputEvent]) {} // Never seize, remap or duplicate native USB input.
    public func reset() {}
}
public enum VirtualHIDOutput {
    public static let blocker = "No authorized virtual-HID provisioning is configured. CoreHID requires macOS 15+ and com.apple.developer.hid.virtual.device; ad-hoc signing does not grant it. IOHIDUserDevice availability and game recognition require separate authorization/runtime tests. SDL and GameController output are unverified."
}
public final class KeyboardMouseOutput: ControllerOutputBackend {
    public let mode: OutputMode = .keyboardMouse
    private var keys: Set<UInt16> = [], buttons: Set<Int> = []
    private var remainder = Stick()
    private let source = CGEventSource(stateID:.hidSystemState)
    private let protected: Bool
    private var watchdog: ReleaseWatchdogClient?
    public var safetyReady: Bool { !protected || watchdog?.running == true }
    public init(protectCrash: Bool = false) {
        protected = protectCrash
        if protectCrash { watchdog = ReleaseWatchdogClient() }
    }
    public static var authorized: Bool { AXIsProcessTrusted() }
    @MainActor public static func requestPermission() { _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String:true] as CFDictionary) }
    private var flags: CGEventFlags {
        var flags: CGEventFlags = []
        if !keys.isDisjoint(with:[54,55]) { flags.insert(.maskCommand) }
        if !keys.isDisjoint(with:[56,60]) { flags.insert(.maskShift) }
        if !keys.isDisjoint(with:[58,61]) { flags.insert(.maskAlternate) }
        if !keys.isDisjoint(with:[59,62]) { flags.insert(.maskControl) }
        return flags
    }
    public func send(_ events: [OutputEvent]) {
        watchdog?.heartbeat()
        for event in events {
            switch event {
            case let .key(key,down):
                if down && protected && watchdog?.track("k",Int(key),true) != true { continue }
                if down { keys.insert(key) } else { keys.remove(key) }
                let e = CGEvent(keyboardEventSource:source,virtualKey:key,keyDown:down); e?.flags = flags; e?.post(tap:.cghidEventTap)
                if !down { _ = watchdog?.track("k",Int(key),false) }
            case let .mouseButton(button,down):
                if down && protected && watchdog?.track("m",button,true) != true { continue }
                if down { buttons.insert(button) } else { buttons.remove(button) }
                let point = CGEvent(source:source)?.location ?? .zero
                let type: CGEventType = button == 0 ? (down ? .leftMouseDown : .leftMouseUp) : button == 1 ? (down ? .rightMouseDown : .rightMouseUp) : (down ? .otherMouseDown : .otherMouseUp)
                let e = CGEvent(mouseEventSource:source,mouseType:type,mouseCursorPosition:point,mouseButton:CGMouseButton(rawValue:UInt32(button))!)
                e?.flags = flags; e?.post(tap:.cghidEventTap)
                if !down { _ = watchdog?.track("m",button,false) }
            case let .move(x,y):
                remainder.x += x; remainder.y += y
                let dx = remainder.x.rounded(.towardZero), dy = remainder.y.rounded(.towardZero)
                remainder.x -= dx; remainder.y -= dy
                if dx == 0 && dy == 0 { continue }
                let point = CGEvent(source:source)?.location ?? .zero
                let button = buttons.sorted().first
                let type: CGEventType = button == 0 ? .leftMouseDragged : button == 1 ? .rightMouseDragged : button == 2 ? .otherMouseDragged : .mouseMoved
                let e = CGEvent(mouseEventSource:source,mouseType:type,mouseCursorPosition:CGPoint(x:point.x+dx,y:point.y+dy),mouseButton:CGMouseButton(rawValue:UInt32(button ?? 0))!)
                e?.setIntegerValueField(.mouseEventDeltaX,value:Int64(dx)); e?.setIntegerValueField(.mouseEventDeltaY,value:Int64(dy))
                e?.flags = flags; e?.post(tap:.cghidEventTap)
            }
        }
    }
    public func reset() {
        send(keys.sorted().map { .key($0,false) } + buttons.sorted().map { .mouseButton($0,false) })
        remainder = Stick()
    }
    deinit { reset() }
}
/// All mutation and CGEvent posting is serialized by this lock, including the timer watchdog.
public final class OutputPipeline: @unchecked Sendable {
    private let lock = NSLock(), engine = InputMappingEngine()
    private var backend: any ControllerOutputBackend = MonitorOnlyOutput()
    private var profile = GameProfile.defaults[1]
    private var enabled = false, lastInput = 0.0
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var timer: DispatchSourceTimer?
    public var isEnabled: Bool { lock.withLock { enabled } }
    public init() {
        let t = DispatchSource.makeTimerSource(queue:DispatchQueue(label:"VitaBridge.output",qos:.userInteractive))
        t.schedule(deadline:.now(),repeating:.milliseconds(8),leeway:.milliseconds(1))
        t.setEventHandler { [weak self] in self?.tick() }; t.resume(); timer = t
    }
    @discardableResult public func configure(mode: OutputMode, enabled: Bool, profile: GameProfile) -> Bool {
        lock.withLock {
            backend.send(engine.reset()); backend.reset()
            self.enabled = enabled && mode == .keyboardMouse && KeyboardMouseOutput.authorized
            self.profile = profile
            switch mode {
            case .keyboardMouse:
                let keyboard = KeyboardMouseOutput(protectCrash:self.enabled); backend = keyboard
                if !keyboard.safetyReady { self.enabled = false }
            case .nativeUSB: backend = NativeUSBPassthroughOutput()
            default: backend = MonitorOnlyOutput()
            }
            lastInput = 0
            lastTick = ProcessInfo.processInfo.systemUptime
            return self.enabled
        }
    }
    public func receive(_ state: ControllerState?) {
        lock.withLock {
            guard let state else { backend.send(engine.reset()); lastInput = 0; return }
            lastInput = state.receivedAt
            if enabled { backend.send(engine.update(state,profile:profile)) }
        }
    }
    private func tick() {
        lock.withLock {
            let now = ProcessInfo.processInfo.systemUptime
            let elapsed = now - lastTick
            lastTick = now
            guard enabled else { return }
            if let keyboard = backend as? KeyboardMouseOutput, !keyboard.safetyReady {
                enabled = false; backend.send(engine.reset()); backend.reset(); return
            }
            if now-lastInput > 0.3 || !KeyboardMouseOutput.authorized { backend.send(engine.reset()); return }
            backend.send(engine.tick(seconds:elapsed))
        }
    }
    public func pause() { lock.withLock { enabled = false; backend.send(engine.reset()); backend.reset() } }
    deinit { timer?.cancel(); backend.send(engine.reset()); backend.reset() }
}
