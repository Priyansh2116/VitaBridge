import Foundation
import VitaProtocol

public enum StickAssignment: String, Codable, CaseIterable, Sendable { case disabled, wasd, arrows, mouse }
public struct InputBinding: Codable, Equatable, Sendable {
    public var keys: [UInt16] = []
    public var mouse: Int? = nil // 0 left, 1 right, 2 middle
    public init(keys: [UInt16] = [], mouse: Int? = nil) { self.keys = keys; self.mouse = mouse }
}
public struct Calibration: Codable, Equatable, Sendable {
    public var center = Stick(), scale = Stick(x: 1, y: 1)
    public var invertX = false, invertY = false
    public init() {}
    public func apply(_ s: Stick, deadZone: Double, sensitivity: Double) -> Stick {
        var x = (s.x-center.x)*scale.x*(invertX ? -1 : 1)
        var y = (s.y-center.y)*scale.y*(invertY ? -1 : 1)
        let length = hypot(x,y)
        if length <= deadZone { return Stick() }
        let magnitude = min(1, (length-deadZone)/(1-deadZone)*sensitivity)
        x = x/length*magnitude; y = y/length*magnitude
        return Stick(x:x,y:y)
    }
}
public struct GameProfile: Codable, Equatable, Identifiable, Sendable {
    public var version = 1
    public var id = UUID()
    public var name: String
    public var bindings: [String: InputBinding] = [:]
    public var left: StickAssignment = .wasd, right: StickAssignment = .mouse
    public var deadZone = 0.18, sensitivity = 1.0, mouseSpeed = 900.0
    public var leftCalibration = Calibration(), rightCalibration = Calibration()
    public init(name: String) { self.name = name }
    public func validated() throws -> GameProfile {
        guard version == 1, !name.isEmpty, name.count <= 100,
              deadZone.isFinite, (0...0.9).contains(deadZone), sensitivity.isFinite, (0.1...5).contains(sensitivity),
              mouseSpeed.isFinite, (1...5000).contains(mouseSpeed), bindings.count <= 64 else { throw ProfileError.invalid }
        for b in bindings.values {
            guard b.keys.count <= 8, b.keys.allSatisfy({ $0 <= 127 }), b.mouse == nil || (0...2).contains(b.mouse!) else { throw ProfileError.invalid }
        }
        for c in [leftCalibration, rightCalibration] {
            guard [c.center.x,c.center.y,c.scale.x,c.scale.y].allSatisfy(\.isFinite),
                  abs(c.center.x) <= 1, abs(c.center.y) <= 1, (0.1...4).contains(c.scale.x), (0.1...4).contains(c.scale.y) else { throw ProfileError.invalid }
        }
        return self
    }
    public static var defaults: [GameProfile] {
        var p = GameProfile(name: "Keyboard Gaming")
        let defaults: [(VitaButton, UInt16)] = [(.cross,49),(.circle,53),(.square,14),(.triangle,15),(.l,56),(.r,59),(.start,36),(.select,48),(.up,126),(.down,125),(.left,123),(.right,124)]
        for (button,key) in defaults { p.bindings[String(button.rawValue)] = InputBinding(keys:[key]) }
        var fps = p; fps.id = UUID(); fps.name = "FPS Keyboard/Mouse"
        fps.bindings[String(VitaButton.r.rawValue)] = InputBinding(mouse:0)
        fps.bindings[String(VitaButton.l.rawValue)] = InputBinding(mouse:1)
        var emulator = p; emulator.id = UUID(); emulator.name = "Emulator"; emulator.right = .disabled
        var standard = GameProfile(name: "Standard Gamepad"); standard.left = .disabled; standard.right = .disabled
        return [standard,p,fps,emulator]
    }
}
public enum ProfileError: Error { case invalid, tooLarge }
public enum ProfileStore {
    public static func load(_ url: URL) throws -> [GameProfile] {
        guard (try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0) <= 1_048_576 else { throw ProfileError.tooLarge }
        let profiles = try JSONDecoder().decode([GameProfile].self, from: Data(contentsOf:url))
        guard !profiles.isEmpty, profiles.count <= 100, Set(profiles.map(\.id)).count == profiles.count else { throw ProfileError.invalid }
        return try profiles.map { try $0.validated() }
    }
    public static func save(_ profiles: [GameProfile], to url: URL) throws {
        guard !profiles.isEmpty, profiles.count <= 100, Set(profiles.map(\.id)).count == profiles.count else { throw ProfileError.invalid }
        _ = try profiles.map { try $0.validated() }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]
        try FileManager.default.createDirectory(at:url.deletingLastPathComponent(), withIntermediateDirectories:true)
        try encoder.encode(profiles).write(to:url, options:.atomic)
    }
}
