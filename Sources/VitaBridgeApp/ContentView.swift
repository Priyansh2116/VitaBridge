import SwiftUI
import VitaProtocol
import VitaTransport
import ControllerEngine
import OutputBackends

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @State private var page = "Dashboard"
    var body: some View {
        NavigationSplitView {
            VStack(alignment:.leading,spacing:8) {
                Label("VitaBridge",systemImage:"gamecontroller.fill").font(.title2.bold()).padding(.bottom,28)
                ForEach(["Dashboard","Controller Test","Mapping Editor","Settings"],id:\.self) { name in
                    Button { page = name } label: {
                        Label(name,systemImage:icon(name)).frame(maxWidth:.infinity,alignment:.leading).padding(10)
                            .background(page == name ? Color.blue.opacity(0.2) : .clear,in:RoundedRectangle(cornerRadius:8))
                    }.buttonStyle(.plain)
                }
                Spacer()
                Label(model.outputEnabled ? "Output enabled" : "Output paused",systemImage:model.outputEnabled ? "bolt.fill" : "pause.circle")
                    .foregroundStyle(model.outputEnabled ? .green : .secondary).font(.caption)
                Text("macOS companion · VitaPad-NG").font(.caption2).foregroundStyle(.secondary)
            }.padding(20).navigationSplitViewColumnWidth(220)
        } detail: {
            ScrollView {
                VStack(alignment:.leading,spacing:24) {
                    HStack { VStack(alignment:.leading,spacing:6) { Text(page).font(.largeTitle.bold()); Text(subtitle).foregroundStyle(.secondary) }; Spacer() }
                    switch page {
                    case "Controller Test": ControllerTestView()
                    case "Mapping Editor": MappingEditorView()
                    case "Settings": SettingsView()
                    default: DashboardView()
                    }
                }.padding(28).frame(maxWidth:1000,alignment:.leading).frame(maxWidth:.infinity)
            }.background(Color(nsColor:.windowBackgroundColor))
        }.frame(minWidth:900,minHeight:650)
        .alert("VitaBridge",isPresented:Binding(get:{ !model.message.isEmpty },set:{ if !$0 { model.message = "" } })) { Button("OK") { model.message = "" } } message: { Text(model.message) }
    }
    var subtitle: String { switch page { case "Dashboard": "Your Vita, connected to your Mac."; case "Controller Test": "Inspect live input from Wi-Fi or native controllers."; case "Mapping Editor": "Build a profile for the way you play."; default: "Connection, output and permissions." } }
    func icon(_ name: String) -> String { switch name { case "Dashboard":"square.grid.2x2"; case "Controller Test":"gamecontroller"; case "Mapping Editor":"slider.horizontal.3"; default:"gearshape" } }
}
struct Metric: View {
    let title: String, value: String, icon: String
    var body: some View { VStack(alignment:.leading,spacing:12) { Label(title,systemImage:icon).font(.caption).foregroundStyle(.secondary); Text(value).font(.title3.weight(.semibold)).lineLimit(2) }.frame(maxWidth:.infinity,minHeight:65,alignment:.leading).padding(16).background(.quaternary.opacity(0.45),in:RoundedRectangle(cornerRadius:12)) }
}
struct DashboardView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment:.leading,spacing:20) {
            GroupBox {
                HStack(spacing:16) {
                    Image(systemName:"gamecontroller.fill").font(.system(size:44)).foregroundStyle(.blue)
                    VStack(alignment:.leading,spacing:8) {
                        Text(model.snapshot.status).font(.title3.bold())
                        Text(model.demo ? "SIMULATED · loopback network input" : "Wi-Fi · \(model.snapshot.host.isEmpty ? "No Vita connected" : model.snapshot.host)").foregroundStyle(.secondary)
                    }; Spacer()
                    Button("Disconnect") { model.disconnect() }
                }.padding(16)
            }
            HStack {
                Metric(title:"Battery",value:model.snapshot.state.battery.map { "\($0)%" } ?? "Not provided",icon:"battery.75percent")
                Metric(title:"Packet rate",value:String(format:"%.0f pkt/s",model.snapshot.packetsPerSecond),icon:"waveform.path")
                Metric(title:"Receive interval",value:String(format:"%.1f ms",model.snapshot.intervalMS),icon:"timer")
            }
            Text("Receive interval is packet spacing at this Mac. Network latency is unavailable because the protocol clocks are not synchronized.").font(.caption).foregroundStyle(.secondary)
            GroupBox("Connect over Wi-Fi") {
                VStack(alignment:.leading,spacing:12) {
                    HStack { TextField("Vita private IPv4 address",text:$model.manualIP); Button("Connect") { model.connect() }.buttonStyle(.borderedProminent); Button("Discover") { model.discover() } }
                    HStack { Button("Start Loopback Demo") { model.startDemo() }; Text("Uses real TCP + UDP and the production decoder.").font(.caption).foregroundStyle(.secondary) }
                }.padding(10)
            }
            GroupBox("Controller output") {
                VStack(alignment:.leading,spacing:12) {
                    Picker("Mode",selection:$model.mode) { ForEach(OutputMode.allCases,id:\.self) { Text($0.rawValue).tag($0) } }.onChange(of:model.mode) { model.updateOutput() }
                    Picker("Profile",selection:$model.selectedID) { ForEach(model.profiles) { Text($0.name).tag($0.id) } }.onChange(of:model.selectedID) { model.selectProfile() }
                    HStack {
                        Button(model.outputEnabled ? "Pause Output" : "Enable Keyboard / Mouse") { if model.outputEnabled { model.pause() } else { model.enableOutput() } }.disabled(model.mode != .keyboardMouse)
                        Text(model.outputEnabled ? "Active · focus your game to use input" : "Paused · enabling is always explicit").font(.caption).foregroundStyle(.secondary)
                    }
                    if model.mode == .nativeUSB { Text("USB input goes directly to games. VitaBridge observes without taking exclusive access or generating duplicate events.").font(.caption) }
                    if model.mode == .virtualHID { Text(VirtualHIDOutput.blocker).font(.caption).foregroundStyle(.orange) }
                }.padding(10)
            }
            USBInventoryView()
        }
    }
}
struct USBInventoryView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        GroupBox("Native controller discovery") {
            VStack(alignment:.leading,spacing:10) {
                if model.usbDevices.isEmpty { Text("No HID gamepads found. Plug in the Vita with USB mode enabled.").foregroundStyle(.secondary) }
                ForEach(model.usbDevices) { d in
                    HStack { Image(systemName:"cable.connector"); VStack(alignment:.leading) { Text(d.name); Text("\(d.transport) · \(d.identity) · \(d.vitaCandidate ? "VitaPad-compatible identity (DS4 may also be a real Sony controller)" : "Other controller")").font(.caption).foregroundStyle(.secondary) } }
                }
                Text("GameController visible: \(model.gcNames.isEmpty ? "none" : model.gcNames.joined(separator:", "))").font(.caption)
                Text(model.usbStatus).font(.caption2).foregroundStyle(.secondary)
                Text("On Vita: hold L + R + Start → Connection → USB, as a DualShock 4 (or standard gamepad) → Start. Homebrew support and Enable Unsafe Homebrew are required by VitaPad-NG.").font(.caption).textSelection(.enabled)
            }.frame(maxWidth:.infinity,alignment:.leading).padding(10)
        }
    }
}
struct ControllerTestView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment:.leading,spacing:20) {
            Toggle("Show native USB / GameController input",isOn:$model.testingUSB).onChange(of:model.testingUSB) { model.pause() }
            if model.testingUSB && !model.gcNames.isEmpty { Picker("GameController device",selection:$model.selectedGC) { ForEach(Array(model.gcNames.enumerated()),id:\.offset) { i,name in Text(name).tag(i) } } }
            let s = model.displayedState
            VStack(spacing:14) {
                HStack { button(.l,s); Spacer(); button(.ps,s); Spacer(); button(.r,s) }
                HStack(spacing:20) {
                    VStack { button(.up,s); HStack { button(.left,s); button(.down,s); button(.right,s) } }
                    VStack(spacing:12) {
                        Text(model.testingUSB ? "NATIVE CONTROLLER" : model.demo ? "SIMULATED VITA" : "VITA INPUT").font(.caption.monospaced()).foregroundStyle(.secondary)
                        HStack(spacing:24) { StickIndicator(title:"Left",stick:s.left); StickIndicator(title:"Right",stick:s.right) }
                    }.frame(maxWidth:.infinity)
                    VStack { button(.triangle,s); HStack { button(.square,s); button(.circle,s) }; button(.cross,s) }
                }
                HStack { button(.select,s); button(.start,s); Spacer(); button(.l1,s); button(.r1,s); button(.l3,s); button(.r3,s) }
            }.padding(24).background(Color.white.opacity(0.04),in:RoundedRectangle(cornerRadius:44)).overlay(RoundedRectangle(cornerRadius:44).stroke(.white.opacity(0.12)))
            HStack {
                touchPanel("Front touch",s.front)
                touchPanel("Rear touch",s.rear)
            }
            Grid(alignment:.leading,horizontalSpacing:24,verticalSpacing:8) {
                GridRow { Text("Packets received"); Text("\(model.snapshot.packets)"); Text("Loss / reordered / malformed"); Text("\(model.snapshot.lost) / \(model.snapshot.reordered) / \(model.snapshot.malformed)") }
                GridRow { Text("Sequence"); Text(s.sequence.map(String.init) ?? "Unavailable"); Text("Vita timestamp (µs, wraps)"); Text(s.timestamp.map(String.init) ?? "Unavailable") }
            }.font(.caption.monospaced()).textSelection(.enabled)
            Text("Accelerometer: \(vector(s.accel)) G\nGyroscope: \(vector(s.gyro)) rad/s").font(.caption.monospaced()).foregroundStyle(.secondary)
            if model.testingUSB { USBInventoryView() }
        }
    }
    func button(_ b: VitaButton,_ s: ControllerState) -> some View { Text(b.title).font(.caption.bold()).frame(minWidth:40,minHeight:30).padding(.horizontal,5).background(s.pressed(b) ? Color.blue : Color.white.opacity(0.07),in:RoundedRectangle(cornerRadius:8)) }
    func vector(_ v: [Float]?) -> String { v?.map { String(format:"%.3f",$0) }.joined(separator:", ") ?? "Not exposed" }
    func touchPanel(_ title: String,_ points: [TouchPoint]) -> some View {
        VStack(alignment:.leading) { Text("\(title) · \(points.count) contacts").font(.caption)
            GeometryReader { g in ZStack { RoundedRectangle(cornerRadius:8).fill(.white.opacity(0.05)); ForEach(Array(points.enumerated()),id:\.offset) { _,p in Circle().fill(.blue).frame(width:12,height:12).position(x:Double(p.x)/1920*g.size.width,y:Double(p.y)/1088*g.size.height) } } }.frame(height:95)
        }.frame(maxWidth:.infinity)
    }
}
struct StickIndicator: View {
    let title: String, stick: Stick
    var body: some View { VStack(spacing:8) { ZStack { Circle().stroke(.white.opacity(0.25),lineWidth:1).frame(width:90,height:90); Rectangle().fill(.white.opacity(0.1)).frame(width:1,height:90); Rectangle().fill(.white.opacity(0.1)).frame(width:90,height:1); Circle().fill(.blue).frame(width:22,height:22).offset(x:stick.x*34,y:stick.y*34) }; Text(title).font(.caption.bold()); Text(String(format:"%+.3f  %+.3f",stick.x,stick.y)).font(.system(size:10,design:.monospaced)) } }
}
