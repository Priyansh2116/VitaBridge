// Compiled with the production UI sources by capture-readme-screenshots.sh.
// Captures only this process's rendered views; never records the user's desktop.
import AppKit
import SwiftUI
import Foundation
import ControllerEngine

@MainActor final class ScreenshotDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var window: NSWindow!
    private let destination = URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
    func applicationDidFinishLaunching(_ notification: Notification) {
        do { try FileManager.default.createDirectory(at:destination,withIntermediateDirectories:true) }
        catch { fail(error.localizedDescription); return }
        UserDefaults.standard.setVolatileDomain(["manualIP":""],forName:UserDefaults.argumentDomain)
        model = AppModel()
        // Public defaults in memory only: never save or publish the user's profiles/IP.
        model.profiles = GameProfile.defaults
        model.selectedID = model.profiles[1].id
        model.mode = .monitor; model.message = ""
        model.pause()
        window = NSWindow(contentRect:NSRect(x:0,y:0,width:1220,height:900),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.title = "VitaBridge"; window.isReleasedWhenClosed = false
        show("Dashboard"); window.center(); window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps:true)
        model.startDemo()
        awaitInput(deadline:ProcessInfo.processInfo.systemUptime+12)
    }
    private func show(_ page: String) {
        window.contentView = NSHostingView(rootView:ContentView(initialPage:page).environmentObject(model).preferredColorScheme(.dark))
    }
    private func awaitInput(deadline: Double) {
        if model.snapshot.packets >= 80 && model.snapshot.state.sequence != nil {
            captureAfterRender(page:"Dashboard",filename:"dashboard.png") { [self] in
                show("Controller Test")
                captureAfterRender(page:"Controller Test",filename:"controller-test.png") { [self] in
                    model.shutdown(); print("Captured two production UI screens with live loopback input; output paused."); NSApp.terminate(nil)
                }
            }
        } else if ProcessInfo.processInfo.systemUptime > deadline {
            fail("Loopback input unavailable: \(model.snapshot.status). Stop other demos using ports 15000/15001.")
        } else {
            DispatchQueue.main.asyncAfter(deadline:.now()+0.1) { [self] in awaitInput(deadline:deadline) }
        }
    }
    private func captureAfterRender(page: String,filename: String,completion: @escaping @MainActor () -> Void) {
        DispatchQueue.main.asyncAfter(deadline:.now()+0.8) { [self] in
            guard let content = window.contentView else { fail("No \(page) content view"); return }
            let view = content.superview ?? content
            view.layoutSubtreeIfNeeded(); window.displayIfNeeded()
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in:view.bounds) else { fail("Cannot allocate \(page) screenshot"); return }
            view.cacheDisplay(in:view.bounds,to:bitmap)
            guard let data = bitmap.representation(using:.png,properties:[:]) else { fail("Cannot encode \(page) screenshot"); return }
            do { try data.write(to:destination.appendingPathComponent(filename),options:.atomic); completion() }
            catch { fail(error.localizedDescription) }
        }
    }
    private func fail(_ text: String) {
        FileHandle.standardError.write(Data((text+"\n").utf8)); model?.shutdown(); exit(1)
    }
}
@main enum ReadmeScreenshotCapture {
    @MainActor static func main() {
        guard CommandLine.arguments.count == 2 else { fatalError("Pass the output directory") }
        let application = NSApplication.shared
        application.setActivationPolicy(.regular)
        let delegate = ScreenshotDelegate(); application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}
