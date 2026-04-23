import SwiftUI

struct MemberEditorView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var member: Member
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消") { dismiss() }
                    .padding()
                Spacer()
                Text("编辑成员")
                    .font(.headline)
                Spacer()
                Button("完成") { dismiss() }
                    .padding()
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            Form {
                Section(header: Text("应用信息")) {
                    TextField("应用名称", text: $member.name)
                    TextField("Bundle Identifier", text: $member.bundleId)
                        .foregroundColor(.secondary)
                        .font(.system(.caption, design: .monospaced))
                }
                
                Section(header: Text("窗口布局")) {
                    HStack {
                        Text("当前布局")
                        Spacer()
                        Button("捕捉当前窗口") {
                            if let layout = WindowManager.shared.saveLayout(for: member.bundleId) {
                                member.layout = layout
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("坐标: (\(Int(member.layout.x)), \(Int(member.layout.y)))")
                        Text("尺寸: \(Int(member.layout.width)) x \(Int(member.layout.height))")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Section(header: Text("启动配置")) {
                    TextField("启动目录", text: Binding(
                        get: { member.launchConfig.directory ?? "" },
                        set: { member.launchConfig.directory = $0.isEmpty ? nil : $0 }
                    ))
                    
                    // 简化处理 URL 列表，仅支持一个主 URL
                    TextField("启动 URL", text: Binding(
                        get: { member.launchConfig.urls?.first ?? "" },
                        set: { member.launchConfig.urls = [$0] }
                    ))
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 400, height: 500)
    }
}
