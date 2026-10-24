import SwiftUI
import AppKit
import ServiceManagement
import VitaProtocol
import VitaTransport
import ControllerEngine
import OutputBackends

@MainActor final class AppModel: ObservableObject {
    @Published var snapshot = ConnectionSnapshot()
    @Published var usbDevices: [USBDeviceInfo] = []
    @Published var gcNames: [String] = []
    @Published var usbState = ControllerState()
    @Published var usbStatus = ""
    @Published var profiles = GameProfile.defaults
    @Published var selectedID = UUID()
    @Published var mode: OutputMode = .monitor
    @Published var outputEnabled = false
    @Published var message = ""
    @Published var accessibility = false
    @Published var manualIP: String { didSet { UserDefaults.standard.set(manualIP,forKey:"manualIP") } }
    @Published var autoReconnect: Bool { didSet { UserDefaults.standard.set(autoReconnect,forKey:"autoReconnect"); connection.setAutoReconnect(autoReconnect) } }
    @Published var testingUSB = false
    @Published var selectedGC = 0
    @Published var demo = false
    @Published var loginEnabled = false
    let pipeline: OutputPipeline
    let connection: VitaConnectionManager
    let usb = NativeUSBControllerObserver()
    private let simulator = LoopbackSimulator()
    private var timer: Timer?, counter = 0
    private var notifications: [NSObjectProtocol] = []
    private var wasConnectedBeforeSleep = false
    private let profileURL: URL
    var selectedIndex: Int { profiles.firstIndex { $0.id == selectedID } ?? 0 }
    var profile: GameProfile { get { profiles[selectedIndex] } set { profiles[selectedIndex] = newValue } }
    var displayedState: ControllerState { testingUSB ? usbState : snapshot.state }
    init() {
        let pipe = OutputPipeline(); pipeline = pipe
        connection = VitaConnectionManager { pipe.receive($0) }
        manualIP = UserDefaults.standard.string(forKey:"manualIP") ?? ""
        autoReconnect = UserDefaults.standard.object(forKey:"autoReconnect") as? Bool ?? true
        profileURL = FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0].appendingPathComponent("VitaBridge/profiles.json")
        selectedID = profiles[1].id
        if FileManager.default.fileExists(atPath:profileURL.path) {
            do { profiles = try ProfileStore.load(profileURL); selectedID = profiles[0].id }
            catch { message = "Could not load profiles: \(error). Defaults are available; the original file has been preserved." }
        }
        if let id = UserDefaults.standard.string(forKey:"profileID"), let uuid = UUID(uuidString:id), profiles.contains(where:{$0.id == uuid}) { selectedID = uuid }
        if let raw = UserDefaults.standard.string(forKey:"mode"), let saved = OutputMode(rawValue:raw) { mode = saved }
        connection.setAutoReconnect(autoReconnect)
        loginEnabled = SMAppService.mainApp.status == .enabled
        timer = Timer.scheduledTimer(withTimeInterval:1.0/30,repeats:true) { [weak self] _ in MainActor.assumeIsolated { self?.refresh() } }
        let center = NSWorkspace.shared.notificationCenter
        notifications.append(center.addObserver(forName:NSWorkspace.willSleepNotification,object:nil,queue:.main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }; self.wasConnectedBeforeSleep = self.snapshot.status != "Disconnected"
                self.pause(); self.connection.disconnect()
            }
        })
        notifications.append(center.addObserver(forName:NSWorkspace.didWakeNotification,object:nil,queue:.main) { [weak self] _ in
            MainActor.assumeIsolated { if let self, self.autoReconnect, self.wasConnectedBeforeSleep { if self.demo { self.startDemo() } else { self.connect() } } }
        })
    }
    func refresh() {
        snapshot = connection.read(); accessibility = KeyboardMouseOutput.authorized
        if outputEnabled && !accessibility { pause(); message = "Accessibility permission was revoked. Output paused." }
        if outputEnabled && !pipeline.isEnabled { outputEnabled = false; message = "Output paused because the independent release watchdog stopped." }
        counter += 1
        if counter % 30 == 0 { usb.refresh(); usbDevices = usb.devices; gcNames = usb.controllerNames; usbStatus = usb.status }
        usb.sampleGameController(index:selectedGC); usbState = usb.state
    }
    func connect() { pause(); simulator.stop(); demo = false; connection.connect(host:manualIP.trimmingCharacters(in:.whitespacesAndNewlines)); testingUSB = false }
    func discover() { pause(); simulator.stop(); demo = false; connection.connect(); testingUSB = false }
    func disconnect() { pause(); connection.disconnect(); simulator.stop(); demo = false }
    func startDemo() {
        disconnect(); demo = true
        simulator.start { [weak self] error in Task { @MainActor in self?.message = error } }
        connection.connect(host:"127.0.0.1",ports:.demo); testingUSB = false
    }
    func pause() { outputEnabled = false; pipeline.pause() }
    func updateOutput() {
        pause(); UserDefaults.standard.set(mode.rawValue,forKey:"mode")
        pipeline.configure(mode:mode,enabled:false,profile:profile)
        if mode == .virtualHID { message = VirtualHIDOutput.blocker }
    }
    func enableOutput() {
        guard mode == .keyboardMouse else { return }
        guard KeyboardMouseOutput.authorized else { message = "VitaBridge needs Accessibility access to send your configured keys and mouse events. Use Grant Accessibility in Settings, then enable output again."; return }
        guard snapshot.status.hasPrefix("Connected"), !testingUSB else { message = "Connect Wi-Fi or the loopback demo before enabling output. USB input passes directly to games."; return }
        outputEnabled = pipeline.configure(mode:mode,enabled:true,profile:profile)
        if !outputEnabled { message = "Output could not start its independent key-release watchdog. Run the packaged VitaBridge.app and check permissions." }
    }
    func selectProfile() {
        pause(); UserDefaults.standard.set(selectedID.uuidString,forKey:"profileID")
        pipeline.configure(mode:mode,enabled:false,profile:profile)
    }
    func save() {
        do { try ProfileStore.save(profiles,to:profileURL); selectProfile(); message = "Profiles saved." }
        catch { message = "Profile save failed: \(error)" }
    }
    func duplicate() { pause(); var p = profile; p.id = UUID(); p.name += " Copy"; profiles.append(p); selectedID = p.id; save() }
    func resetProfile() {
        pause(); let id = profile.id, name = profile.name
        var p = GameProfile.defaults.first(where:{$0.name == name}) ?? GameProfile.defaults[1]; p.id = id; p.name = name; profile = p
    }
    func importProfiles() {
        pause(); let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do { let loaded = try ProfileStore.load(url); profiles = loaded; selectedID = loaded[0].id; save() }
            catch { message = "Import rejected: \(error)" }
        }
    }
    func exportProfiles() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "VitaBridge-profiles.json"
        if panel.runModal() == .OK, let url = panel.url { do { try ProfileStore.save(profiles,to:url) } catch { message = "Export failed: \(error)" } }
    }
    func setLogin(_ enabled: Bool) {
        do { if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; loginEnabled = SMAppService.mainApp.status == .enabled }
        catch { message = "Launch at login failed: \(error)"; loginEnabled = false }
    }
    func shutdown() { pause(); connection.disconnect(); simulator.stop(); usb.close(); timer?.invalidate() }
}
