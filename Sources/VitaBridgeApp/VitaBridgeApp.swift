import SwiftUI
import AppKit
import VitaProtocol
import OutputBackends

@MainActor final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    var model: AppModel?
    func applicationWillTerminate(_ notification: Notification) { model?.shutdown() }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
struct VitaBridgeApp: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) var delegate
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup("VitaBridge",id:"main") {
            ContentView().environmentObject(model).preferredColorScheme(.dark)
                .onAppear { delegate.model = model }
        }.defaultSize(width:1080,height:740)
        Settings { SettingsView().environmentObject(model).padding(24).frame(width:640).preferredColorScheme(.dark) }
        MenuBarExtra("VitaBridge",systemImage:"gamecontroller") {
            MenuContent().environmentObject(model)
        }
    }
}
struct MenuContent: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openWindow) var openWindow
    var body: some View {
        Text(model.snapshot.status)
        Button("Open VitaBridge") { openWindow(id:"main"); NSApp.activate(ignoringOtherApps:true) }
        Menu("Profile") { ForEach(model.profiles) { p in Button(p.name) { model.selectedID = p.id; model.selectProfile() } } }
        Button(model.outputEnabled ? "Pause Output" : "Enable Keyboard / Mouse") { if model.outputEnabled { model.pause() } else { model.enableOutput() } }.disabled(model.mode != .keyboardMouse)
        Button("Disconnect") { model.disconnect() }
        Divider()
        Button("Quit VitaBridge") { model.shutdown(); NSApp.terminate(nil) }.keyboardShortcut("q")
    }
}

@main enum VitaBridgeLauncher {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--release-watchdog") {
            ReleaseWatchdog.run(auditOnly:CommandLine.arguments.contains("--watchdog-audit"))
        } else { VitaBridgeApp.main() }
    }
}
