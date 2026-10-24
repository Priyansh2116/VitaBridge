import Foundation
import VitaProtocol

public enum OutputEvent: Equatable, Sendable {
    case key(UInt16, Bool), mouseButton(Int, Bool), move(Double, Double)
}
// Caller serializes all access. Compute the union before transitions, so shared keys cannot release each other.
public final class InputMappingEngine {
    private var heldKeys: Set<UInt16> = [], heldMouse: Set<Int> = []
    private var velocity = Stick()
    public init() {}
    public func update(_ state: ControllerState, profile: GameProfile) -> [OutputEvent] {
        var keys: Set<UInt16> = [], mouse: Set<Int> = []; velocity = Stick()
        func add(_ binding: InputBinding?) { guard let binding else { return }; keys.formUnion(binding.keys); if let m = binding.mouse { mouse.insert(m) } }
        for button in VitaButton.allCases where state.pressed(button) { add(profile.bindings[String(button.rawValue)]) }
        if !state.front.isEmpty { add(profile.bindings["frontTouch"]) }
        if !state.rear.isEmpty { add(profile.bindings["rearTouch"]) }
        func stick(_ s: Stick, _ assignment: StickAssignment) {
            if assignment == .mouse { velocity.x += s.x*profile.mouseSpeed; velocity.y += s.y*profile.mouseSpeed }
            let codes: [UInt16]
            switch assignment { case .wasd: codes = [0,2,13,1]; case .arrows: codes = [123,124,126,125]; default: return }
            if s.x < -0.35 { keys.insert(codes[0]) }; if s.x > 0.35 { keys.insert(codes[1]) }
            if s.y < -0.35 { keys.insert(codes[2]) }; if s.y > 0.35 { keys.insert(codes[3]) }
        }
        stick(profile.leftCalibration.apply(state.left, deadZone:profile.deadZone, sensitivity:profile.sensitivity), profile.left)
        stick(profile.rightCalibration.apply(state.right, deadZone:profile.deadZone, sensitivity:profile.sensitivity), profile.right)
        return transition(keys:keys,mouse:mouse)
    }
    public func tick(seconds: Double) -> [OutputEvent] {
        guard velocity.x != 0 || velocity.y != 0 else { return [] }
        return [.move(velocity.x*min(seconds,0.05),velocity.y*min(seconds,0.05))]
    }
    public func reset() -> [OutputEvent] { velocity = Stick(); return transition(keys:[],mouse:[]) }
    private func transition(keys: Set<UInt16>, mouse: Set<Int>) -> [OutputEvent] {
        let modifiers: Set<UInt16> = [54,55,56,60,58,61,59,62,57]
        var events: [OutputEvent] = []
        let released = heldKeys.subtracting(keys).sorted { (modifiers.contains($0) ? 1 : 0, $0) < (modifiers.contains($1) ? 1 : 0, $1) }
        let pressed = keys.subtracting(heldKeys).sorted { (modifiers.contains($0) ? 0 : 1, $0) < (modifiers.contains($1) ? 0 : 1, $1) }
        events += released.map { .key($0,false) }; events += heldMouse.subtracting(mouse).sorted().map { .mouseButton($0,false) }
        events += pressed.map { .key($0,true) }; events += mouse.subtracting(heldMouse).sorted().map { .mouseButton($0,true) }
        heldKeys = keys; heldMouse = mouse
        return events
    }
}
