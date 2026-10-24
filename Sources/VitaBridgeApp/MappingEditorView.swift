import SwiftUI
import VitaProtocol
import ControllerEngine
import OutputBackends

struct MappingEditorView: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        VStack(alignment:.leading,spacing:18) {
            HStack {
                Picker("Profile",selection:$model.selectedID) { ForEach(model.profiles) { Text($0.name).tag($0.id) } }.onChange(of:model.selectedID) { model.selectProfile() }
                Button("Duplicate") { model.duplicate() }; Button("Reset") { model.resetProfile() }; Button("Save") { model.save() }.buttonStyle(.borderedProminent)
            }
            TextField("Profile name",text:Binding(get:{model.profile.name},set:{model.profile.name = $0; model.pause()}))
            Text("Choose a key, mouse click, or enter a comma-separated combination of macOS virtual key codes. Changes pause output; press Save when ready.").font(.caption).foregroundStyle(.secondary)
            GroupBox("Button mappings") {
                VStack(spacing:7) {
                    ForEach(VitaButton.allCases,id:\.rawValue) { b in bindingRow(b.title,String(b.rawValue)) }
                    Divider(); bindingRow("Front touch (any contact)","frontTouch"); bindingRow("Rear touch (any contact)","rearTouch")
                }.padding(10)
            }
            GroupBox("Analog sticks & calibration") {
                VStack(alignment:.leading,spacing:14) {
                    Picker("Left stick",selection:Binding(get:{model.profile.left},set:{model.profile.left = $0; model.pause()})) { ForEach(StickAssignment.allCases,id:\.self) { Text($0.rawValue.capitalized).tag($0) } }
                    Picker("Right stick",selection:Binding(get:{model.profile.right},set:{model.profile.right = $0; model.pause()})) { ForEach(StickAssignment.allCases,id:\.self) { Text($0.rawValue.capitalized).tag($0) } }
                    valueSlider("Dead zone",value:Binding(get:{model.profile.deadZone},set:{model.profile.deadZone = $0; model.pause()}),range:0...0.8)
                    valueSlider("Analog sensitivity",value:Binding(get:{model.profile.sensitivity},set:{model.profile.sensitivity = $0; model.pause()}),range:0.1...5)
                    valueSlider("Mouse speed (pixels/s)",value:Binding(get:{model.profile.mouseSpeed},set:{model.profile.mouseSpeed = $0; model.pause()}),range:50...3000)
                    HStack { Toggle("Invert left X",isOn:Binding(get:{model.profile.leftCalibration.invertX},set:{model.profile.leftCalibration.invertX = $0; model.pause()})); Toggle("Invert left Y",isOn:Binding(get:{model.profile.leftCalibration.invertY},set:{model.profile.leftCalibration.invertY = $0; model.pause()})) }
                    HStack { Toggle("Invert right X",isOn:Binding(get:{model.profile.rightCalibration.invertX},set:{model.profile.rightCalibration.invertX = $0; model.pause()})); Toggle("Invert right Y",isOn:Binding(get:{model.profile.rightCalibration.invertY},set:{model.profile.rightCalibration.invertY = $0; model.pause()})) }
                    HStack { Button("Calibrate Center (sticks at rest)") { model.pause(); model.profile.leftCalibration.center = model.displayedState.left; model.profile.rightCalibration.center = model.displayedState.right }; Button("Reset Calibration") { model.pause(); model.profile.leftCalibration = Calibration(); model.profile.rightCalibration = Calibration() } }
                    valueSlider("Left X range scale",value:Binding(get:{model.profile.leftCalibration.scale.x},set:{model.profile.leftCalibration.scale.x = $0; model.pause()}),range:0.5...2)
                    valueSlider("Left Y range scale",value:Binding(get:{model.profile.leftCalibration.scale.y},set:{model.profile.leftCalibration.scale.y = $0; model.pause()}),range:0.5...2)
                    valueSlider("Right X range scale",value:Binding(get:{model.profile.rightCalibration.scale.x},set:{model.profile.rightCalibration.scale.x = $0; model.pause()}),range:0.5...2)
                    valueSlider("Right Y range scale",value:Binding(get:{model.profile.rightCalibration.scale.y},set:{model.profile.rightCalibration.scale.y = $0; model.pause()}),range:0.5...2)
                }.padding(10)
            }
            HStack { Button("Import Profiles…") { model.importProfiles() }; Button("Export Profiles…") { model.exportProfiles() } }
        }
    }
    func valueSlider(_ title: String,value: Binding<Double>,range: ClosedRange<Double>) -> some View { HStack { Text(title).frame(width:175,alignment:.leading); Slider(value:value,in:range); Text(String(format:"%.2f",value.wrappedValue)).monospacedDigit().frame(width:65) } }
    func bindingRow(_ name: String,_ key: String) -> some View {
        BindingRow(title:name,binding:Binding(get:{model.profile.bindings[key] ?? InputBinding()},set:{ model.pause(); model.profile.bindings[key] = $0 }))
    }
}
struct BindingRow: View {
    let title: String
    @Binding var binding: InputBinding
    @State private var combination = ""
    @State private var invalid = false
    static let keys: [(String,UInt16)] = [("A",0),("D",2),("W",13),("S",1),("Space",49),("Escape",53),("E",14),("R",15),("Return",36),("Tab",48),("Left Shift",56),("Left Control",59),("Left Option",58),("Left Command",55),("Up",126),("Down",125),("Left",123),("Right",124)]
    var body: some View {
        HStack {
            Text(title).frame(width:160,alignment:.leading)
            Menu(binding.keys.isEmpty && binding.mouse == nil ? "Unmapped" : summary) {
                Button("Unmapped") { binding = InputBinding() }
                ForEach(Self.keys,id:\.1) { name,code in Button(name) { binding = InputBinding(keys:[code]) } }
                Divider(); Button("Left Mouse") { binding = InputBinding(mouse:0) }; Button("Right Mouse") { binding = InputBinding(mouse:1) }; Button("Middle Mouse") { binding = InputBinding(mouse:2) }
            }.frame(width:150)
            TextField("Key codes: e.g. 55, 0",text:$combination).textFieldStyle(.roundedBorder).onSubmit { apply() }
            Button("Apply") { apply() }
            if invalid { Image(systemName:"exclamationmark.triangle").foregroundStyle(.orange).help("Use 1–8 comma-separated key codes between 0 and 127, or leave blank.") }
        }.onAppear { sync() }.onChange(of:binding) { sync() }
    }
    var summary: String { if let m = binding.mouse { return ["Left Mouse","Right Mouse","Middle Mouse"][min(2,max(0,m))] }; return binding.keys.map { code in Self.keys.first(where:{$0.1 == code})?.0 ?? String(code) }.joined(separator:" + ") }
    func sync() { combination = binding.keys.map(String.init).joined(separator:", ") }
    func apply() {
        let parts = combination.split(separator:",",omittingEmptySubsequences:false).map { $0.trimmingCharacters(in:.whitespaces) }
        if combination.trimmingCharacters(in:.whitespaces).isEmpty { binding = InputBinding(); invalid = false; return }
        let codes = parts.compactMap(UInt16.init)
        guard codes.count == parts.count, codes.count <= 8, codes.allSatisfy({$0 <= 127}) else { invalid = true; return }
        binding = InputBinding(keys:Array(Set(codes)).sorted()); invalid = false
    }
}
