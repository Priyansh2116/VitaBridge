import SwiftUI
import ServiceManagement
import OutputBackends

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment:.leading,spacing:20) {
            GroupBox("Connection") {
                VStack(alignment:.leading,spacing:14) {
                    Toggle("Launch VitaBridge at login",isOn:Binding(get:{model.loginEnabled},set:{model.setLogin($0)}))
                    Toggle("Automatically reconnect",isOn:$model.autoReconnect)
                    TextField("Manual private IPv4 address",text:$model.manualIP)
                    Text("Discovery uses LAN UDP broadcast on port 5000. Connections use TCP 5000 and outbound UDP 5001. No public listening service is created.").font(.caption).foregroundStyle(.secondary)
                }.padding(10)
            }
            GroupBox("Output and permissions") {
                VStack(alignment:.leading,spacing:14) {
                    Picker("Input mode",selection:$model.mode) { ForEach(OutputMode.allCases,id:\.self) { Text($0.rawValue).tag($0) } }.onChange(of:model.mode) { model.updateOutput() }
                    Label(model.accessibility ? "Accessibility granted" : "Accessibility not granted",systemImage:model.accessibility ? "checkmark.shield" : "lock.shield")
                    Text("Accessibility allows VitaBridge to send keyboard and mouse input to your focused app. Monitor mode and native USB passthrough do not need input injection. Output starts paused and remains paused after sleep.").font(.caption)
                    Button("Grant Accessibility…") { KeyboardMouseOutput.requestPermission() }.disabled(model.accessibility)
                    Text("Edit dead zone, sensitivity, inversion and center calibration per profile in Mapping Editor.").font(.caption).foregroundStyle(.secondary)
                }.padding(10)
            }
            GroupBox("Diagnostics") {
                VStack(alignment:.leading,spacing:8) {
                    Text("\(model.snapshot.status)\nHost: \(model.snapshot.host)\nPackets: \(model.snapshot.packets)\nMissing sequence numbers: \(model.snapshot.lost)\nLate / duplicate packets: \(model.snapshot.reordered)\nMalformed UDP packets: \(model.snapshot.malformed)").font(.caption.monospaced()).textSelection(.enabled)
                    Text("Virtual output: \(VirtualHIDOutput.blocker)").font(.caption).foregroundStyle(.secondary)
                }.frame(maxWidth:.infinity,alignment:.leading).padding(10)
            }
        }
    }
}
