import Foundation

public enum VitaButton: UInt32, CaseIterable, Codable, Sendable {
    case select = 1, l3 = 2, r3 = 4, start = 8, up = 16, right = 32, down = 64, left = 128
    case l = 256, r = 512, l1 = 1024, r1 = 2048
    case triangle = 4096, circle = 8192, cross = 16384, square = 32768, ps = 65536
    public var title: String { String(describing: self).capitalized }
}
public struct Stick: Codable, Equatable, Sendable {
    public var x: Double = 0
    public var y: Double = 0 // positive down, matching Vita wire coordinates
    public init(x: Double = 0, y: Double = 0) { self.x = x; self.y = y }
}
public struct TouchPoint: Codable, Equatable, Sendable {
    public var x: UInt16; public var y: UInt16; public var id: UInt8
}
public struct ControllerState: Equatable, Sendable {
    public var buttons: UInt32 = 0
    public var left = Stick(), right = Stick()
    public var front: [TouchPoint] = [], rear: [TouchPoint] = []
    public var accel: [Float]? = nil, gyro: [Float]? = nil
    public var battery: UInt8? = nil
    public var timestamp: UInt32? = nil, sequence: UInt32? = nil
    public var receivedAt: TimeInterval = 0
    public init() {}
    public func pressed(_ button: VitaButton) -> Bool { buttons & button.rawValue != 0 }
}
public enum ProtocolError: Error, Equatable { case size(Int), magic, touchCount, coordinate, motion, battery, outOfOrder, legacy }
public enum PadDecoder {
    public static let request = Data([86,80,65,68,50,0,0,0])
    public static let hello = Data("VPAD_STREAM\0".utf8)
    public static func decode(_ data: Data, stream: Bool = false) throws -> ControllerState {
        let b = [UInt8](data)
        guard b.count == (stream ? 76 : 68) else { throw b.count == 16 ? ProtocolError.legacy : .size(b.count) }
        if stream && Array(b.prefix(4)) != Array("VPS1".utf8) { throw ProtocolError.magic }
        let o = stream ? 8 : 0
        func u16(_ p: Int) -> UInt16 { UInt16(b[p]) | UInt16(b[p+1]) << 8 }
        func u32(_ p: Int) -> UInt32 { UInt32(u16(p)) | UInt32(u16(p+2)) << 16 }
        func axis(_ p: Int) -> Double { let n = Int(b[p]) - 128; return Double(n) / (n < 0 ? 128 : 127) }
        guard b[o+8] <= 2, b[o+9] <= 2 else { throw ProtocolError.touchCount }
        func points(_ start: Int, _ count: UInt8) throws -> [TouchPoint] {
            try (0..<Int(count)).map { i in
                let p = o + start + 6*i, x = u16(p), y = u16(p+2)
                guard x < 1920, y < 1088 else { throw ProtocolError.coordinate }
                return TouchPoint(x: x, y: y, id: b[p+4])
            }
        }
        var s = ControllerState()
        s.buttons = u32(o); s.left = Stick(x: axis(o+4), y: axis(o+5)); s.right = Stick(x: axis(o+6), y: axis(o+7))
        s.front = try points(12, b[o+8]); s.rear = try points(24, b[o+9])
        let motion = (0..<6).map { Float(bitPattern: u32(o+36+4*$0)) }
        guard motion.allSatisfy(\.isFinite) else { throw ProtocolError.motion }
        s.accel = Array(motion[0..<3]); s.gyro = Array(motion[3..<6])
        s.timestamp = u32(o+60)
        guard b[o+64] <= 100 || b[o+64] == 255 else { throw ProtocolError.battery }
        s.battery = b[o+64] <= 100 ? b[o+64] : nil
        s.sequence = stream ? u32(4) : nil
        s.receivedAt = ProcessInfo.processInfo.systemUptime
        return s
    }
}
public struct SequenceTracker: Sendable {
    public private(set) var last: UInt32?
    public private(set) var lost: UInt64 = 0, reordered: UInt64 = 0
    public init() {}
    public mutating func accept(_ seq: UInt32) throws {
        if let last {
            let delta = Int32(bitPattern: seq &- last)
            guard delta > 0 else { reordered += 1; throw ProtocolError.outOfOrder }
            lost += UInt64(delta - 1)
        }
        last = seq
    }
}
