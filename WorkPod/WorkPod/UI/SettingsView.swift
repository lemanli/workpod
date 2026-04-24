import SwiftUI

struct SettingsView: View {
    @ObservedObject var inputManager = InputManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("设置")
                .font(.title)
                .padding(.bottom)
            
            Group {
                Text("快捷键设置")
                    .font(.headline)
                
                shortcutRow(
                    label: "切换工作舱",
                    current: formatShortcut(key: inputManager.config.cockpitSwitchKey, mods: inputManager.config.cockpitSwitchModifiers),
                    target: .cockpitSwitch
                )
                
                shortcutRow(
                    label: "切换舱内窗口",
                    current: formatShortcut(key: inputManager.config.windowSwitchKey, mods: inputManager.config.windowSwitchModifiers),
                    target: .windowSwitch
                )
                
                Text("提示：按下快捷键切换下一个，增加 Shift 键切换上一个。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            Group {
                Text("通用设置")
                    .font(.headline)
                
                Text("欢迎使用 WorkPod!")
                    .padding(.vertical, 4)
            }
        }
        .padding()
        .frame(width: 400, height: 350)
    }
    
    @ViewBuilder
    func shortcutRow(label: String, current: String, target: RecordingTarget) -> some View {
        HStack {
            Text(label)
            Spacer()
            Button(action: {
                inputManager.recordingTarget = target
            }) {
                Text(inputManager.recordingTarget == target ? "监听中..." : current)
                    .foregroundColor(inputManager.recordingTarget == target ? .blue : .secondary)
                    .padding(4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
    }
    
    func formatShortcut(key: Int, mods: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if mods.contains(.command) { parts.append("Cmd") }
        if mods.contains(.option) { parts.append("Opt") }
        if mods.contains(.control) { parts.append("Ctrl") }
        
        let keyName = key == 48 ? "Tab" : "Key(\(key))"
        parts.append(keyName)
        
        return parts.joined(separator: " + ")
    }
}
