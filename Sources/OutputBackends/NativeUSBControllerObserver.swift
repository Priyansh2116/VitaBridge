import Foundation
import IOKit.hid
import GameController
import VitaProtocol

public struct USBDeviceInfo: Identifiable, Sendable {
    public var id: Int
    public var name: String, transport: String
    public var vendor: Int, product: Int
    public var vitaCandidate: Bool { vendor == 0x054c && (product == 0x5650 || product == 0x09cc) }
    public var identity: String { String(format:"%04X:%04X",vendor,product) }
}
@MainActor public final class NativeUSBControllerObserver {
    private let manager = IOHIDManagerCreate(kCFAllocatorDefault,IOOptionBits(kIOHIDOptionsTypeNone))
    public private(set) var devices: [USBDeviceInfo] = []
    public private(set) var controllerNames: [String] = []
    public private(set) var state = ControllerState()
    public private(set) var rawValues: [String:Int] = [:]
    public private(set) var status = "Not opened"
    public init() {
        let matches = [
            [kIOHIDDeviceUsagePageKey:1,kIOHIDDeviceUsageKey:5],
            [kIOHIDDeviceUsagePageKey:1,kIOHIDDeviceUsageKey:4]
        ]
        IOHIDManagerSetDeviceMatchingMultiple(manager,matches as CFArray)
        IOHIDManagerRegisterInputValueCallback(manager,{ context,_,_,value in
            guard let context else { return }
            MainActor.assumeIsolated { Unmanaged<NativeUSBControllerObserver>.fromOpaque(context).takeUnretainedValue().input(value) }
        },Unmanaged.passUnretained(self).toOpaque())
        IOHIDManagerScheduleWithRunLoop(manager,CFRunLoopGetMain(),CFRunLoopMode.defaultMode.rawValue)
        let result = IOHIDManagerOpen(manager,IOOptionBits(kIOHIDOptionsTypeNone))
        status = result == kIOReturnSuccess ? "HID observer open (non-exclusive)" : "HID access unavailable: \(result). GameController observation remains available."
        refresh()
    }
    public func refresh() {
        let hidDevices = (IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice>) ?? []
        devices = hidDevices.map { d in
            USBDeviceInfo(id:Int(bitPattern:CFHash(d)),name:IOHIDDeviceGetProperty(d,kIOHIDProductKey as CFString) as? String ?? "Gamepad",
                          transport:IOHIDDeviceGetProperty(d,kIOHIDTransportKey as CFString) as? String ?? "Unknown",
                          vendor:IOHIDDeviceGetProperty(d,kIOHIDVendorIDKey as CFString) as? Int ?? 0,
                          product:IOHIDDeviceGetProperty(d,kIOHIDProductIDKey as CFString) as? Int ?? 0)
        }.sorted { $0.id < $1.id }
        controllerNames = GCController.controllers().map { $0.vendorName ?? "GameController device" }
        if !devices.contains(where: { $0.vendor == 0x054c && $0.product == 0x5650 }) && GCController.controllers().isEmpty { state = ControllerState(); rawValues = [:] }
    }
    public func sampleGameController(index: Int = 0) {
        let controllers = GCController.controllers()
        guard controllers.indices.contains(index), let pad = controllers[index].extendedGamepad else { return }
        var s = ControllerState()
        let mapping: [(GCControllerButtonInput?, VitaButton)] = [(pad.buttonA,.cross),(pad.buttonB,.circle),(pad.buttonX,.square),(pad.buttonY,.triangle),
            (pad.dpad.up,.up),(pad.dpad.down,.down),(pad.dpad.left,.left),(pad.dpad.right,.right),
            (pad.leftTrigger,.l),(pad.rightTrigger,.r),(pad.leftShoulder,.l1),(pad.rightShoulder,.r1),
            (pad.buttonMenu,.start),(pad.buttonOptions,.select),(pad.buttonHome,.ps),(pad.leftThumbstickButton,.l3),(pad.rightThumbstickButton,.r3)]
        for (input,button) in mapping where input?.isPressed == true { s.buttons |= button.rawValue }
        s.left = Stick(x:Double(pad.leftThumbstick.xAxis.value),y:-Double(pad.leftThumbstick.yAxis.value))
        s.right = Stick(x:Double(pad.rightThumbstick.xAxis.value),y:-Double(pad.rightThumbstick.yAxis.value))
        s.receivedAt = ProcessInfo.processInfo.systemUptime
        state = s
    }
    private func input(_ value: IOHIDValue) {
        let element = IOHIDValueGetElement(value), device = IOHIDElementGetDevice(element)
        let vendor = IOHIDDeviceGetProperty(device,kIOHIDVendorIDKey as CFString) as? Int
        let product = IOHIDDeviceGetProperty(device,kIOHIDProductIDKey as CFString) as? Int
        guard vendor == 0x054c, product == 0x5650 else { return } // Generic VitaPad descriptor, not arbitrary gamepads.
        let page = IOHIDElementGetUsagePage(element), usage = IOHIDElementGetUsage(element), v = IOHIDValueGetIntegerValue(value)
        rawValues["\(page):\(usage)"] = v
        if page == 9 {
            let buttons: [VitaButton] = [.square,.cross,.circle,.triangle,.l1,.r1,.l,.r,.select,.start,.l3,.r3,.ps]
            if usage > 0 && usage <= buttons.count { let bit = buttons[Int(usage)-1].rawValue; if v != 0 { state.buttons |= bit } else { state.buttons &= ~bit } }
        } else if page == 1 {
            let lo = IOHIDElementGetLogicalMin(element), hi = IOHIDElementGetLogicalMax(element)
            let n = hi > lo ? Double(v-lo)/Double(hi-lo)*2-1 : 0
            switch usage {
            case 0x30: state.left.x = n; case 0x31: state.left.y = n
            case 0x32: state.right.x = n; case 0x35: state.right.y = n
            case 0x39:
                state.buttons &= ~UInt32(0xf0)
                let hats: [UInt32] = [16,48,32,96,64,192,128,144]
                if v >= 0 && v < 8 { state.buttons |= hats[v] }
            default: break
            }
        }
        state.receivedAt = ProcessInfo.processInfo.systemUptime
    }
    public func close() {
        IOHIDManagerUnscheduleFromRunLoop(manager,CFRunLoopGetMain(),CFRunLoopMode.defaultMode.rawValue)
        IOHIDManagerClose(manager,IOOptionBits(kIOHIDOptionsTypeNone))
    }
}
