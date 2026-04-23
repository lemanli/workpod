import SwiftUI

struct CockpitEditorView: View {
    @EnvironmentObject var cockpitManager: CockpitManager
    @Environment(\.dismiss) var dismiss
    
    @State private var cockpit: Cockpit
    @State private var showingWindowPicker = false
    
    init(cockpit: Cockpit) {
        _cockpit = State(initialValue: cockpit)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button("取消") {
                    dismiss()
                }
                .padding()
                
                Spacer()
                
                Text("编辑工作舱")
                    .font(.headline)
                
                Spacer()
                
                Button("保存") {
                    cockpitManager.updateCockpit(cockpit)
                    dismiss()
                }
                .padding()
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Basic Info
                    VStack(alignment: .leading, spacing: 8) {
                        Text("基本信息")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            TextField("工作舱名称", text: $cockpit.name)
                               .textFieldStyle(.roundedBorder)
                               .frame(width: 200)
                            
                            TextField("图标 (SF Symbol)", text: Binding(
                                get: { cockpit.icon ?? "" },
                                set: { cockpit.icon = $0.isEmpty ? nil : $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                    
                    Divider()
                    
                    // Members
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("成员应用")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            HStack {
                                Button(action: {
                                    showingWindowPicker = true
                                }) {
                                    Label("从打开的窗口选择", systemImage: "window.badge.plus")
                                }
                                .buttonStyle(.bordered)
                                
                                Button(action: addMemberManually) {
                                    Label("手动添加", systemImage: "plus.circle.fill")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        
                        ForEach(cockpit.members) { member in
                            MemberRow(member: member, onRemove: { removeMember(member.id) }, onEdit: { editMember(member) })
                        }
                    }
                }
                .padding()
            }
        }
        .frame(width: 500, height: 600)
        .sheet(isPresented: $showingWindowPicker) {
            WindowPickerView { selectedWindow in
                addMemberFromWindow(selectedWindow)
            }
        }
    }
    
    private func addMemberManually() {
        let newMember = Member(
            id: UUID().uuidString,
            bundleId: "",
            name: "新应用",
            launchConfig: LaunchConfig(),
            layout: WindowLayout(x: 0, y: 0, width: 1200, height: 800),
            isPrimary: false
        )
        cockpit.members.append(newMember)
    }
    
    private func addMemberFromWindow(_ window: WindowInfo) {
        guard let bundleId = window.bundleId else {
            print("❌ Selected window has no bundleId")
            return
        }
        
        // Try to get a better name for the app via bundleId if possible, 
        // otherwise use the window title.
        let memberName = window.title
        
        // Capture current layout
        let layout = WindowManager.shared.saveLayout(for: bundleId) ?? 
                     WindowLayout(x: window.bounds.origin.x, y: window.bounds.origin.y, 
                                 width: window.bounds.width, height: window.bounds.height)
        
        let newMember = Member(
            id: UUID().uuidString,
            bundleId: bundleId,
            name: memberName,
            launchConfig: LaunchConfig(),
            layout: layout,
            isPrimary: false
        )
        cockpit.members.append(newMember)
    }
    
    private func removeMember(_ id: String) {
        cockpit.members.removeAll { $0.id == id }
    }
    
    private func editMember(_ member: Member) {
        // TODO: 实现成员编辑器
    }
}

struct MemberRow: View {
    let member: Member
    var onRemove: () -> Void
    var onEdit: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "app.badge")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text(member.name)
                    .font(.body)
                Text(member.bundleId)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            
            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}
