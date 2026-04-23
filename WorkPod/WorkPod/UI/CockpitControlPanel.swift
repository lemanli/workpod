import SwiftUI
import AppKit
import Combine

struct CockpitControlPanel: View {
    @EnvironmentObject var cockpitManager: CockpitManager
    @ObservedObject var windowManager = WindowManager.shared
    
    // Use @State to track the current frontmost app bundle ID
    @State private var frontmostBundleId: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // --- Cockpit Selection List ---
            Text("工作舱")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                ForEach(cockpitManager.cockpits) { cockpit in
                    let isActive = (cockpit.id == cockpitManager.activeCockpitId)
                    
                    Button(action: {
                        cockpitManager.activateCockpit(id: cockpit.id)
                    }) {
                        HStack {
                            Image(systemName: cockpit.icon ?? "macwindow")
                                .foregroundColor(isActive ? .blue : .secondary)
                            Text(cockpit.name)
                                .font(.system(size: 12, weight: isActive ? .bold : .regular))
                                .foregroundColor(isActive ? .primary : .secondary)
                            Spacer()
                            if isActive {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                            }
                        }
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(isActive ? Color.blue.opacity(0.15) : Color.gray.opacity(0.1))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isActive ? Color.blue : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if cockpitManager.cockpits.isEmpty {
                Text("还没有创建工作舱")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            }

            Divider()

            // --- Active Cockpit Members ---
            if let activeId = cockpitManager.activeCockpitId,
               let cockpit = cockpitManager.cockpit(with: activeId) {
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("成员应用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 8) {
                        ForEach(cockpit.members) { member in
                            let isFocused = (frontmostBundleId == member.bundleId)
                            
                            Button(action: {
                                WindowManager.shared.bringToFront(bundleId: member.bundleId, token: CockpitManager.shared.activationToken)
                                let currentToken = CockpitManager.shared.activationToken
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    WindowManager.shared.maximizeWindow(for: member.bundleId, token: currentToken)
                                }
                            }) {
                                HStack {
                                    Image(systemName: "app.badge")
                                        .foregroundColor(isFocused ? .green : .blue)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Text(WindowManager.shared.getAppName(for: member.bundleId))
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.secondary)
                                            Text(member.name)
                                                .font(.system(size: 12))
                                                .foregroundColor(isFocused ? .primary : .primary.opacity(0.8))
                                        }
                                    }
                                    Spacer()
                                    
                                    if isFocused {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.caption)
                                    } else {
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(isFocused ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isFocused ? Color.green : Color.clear, lineWidth: 2)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    if cockpit.members.isEmpty {
                        Text("该工作舱暂无成员")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 10)
                    }
                }
                .padding(.bottom, 10)
            } else {
                Text("请选择一个工作舱以查看成员")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 10)
            }
            
            Spacer()
            
            if cockpitManager.activeCockpitId != nil {
                Text("工作舱活跃中")
                    .font(.caption2)
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 10)
            }
        }
        .padding()
        .frame(width: 240)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 5)
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            self.updateFrontmostApp()
        }
    }
    
    private func updateFrontmostApp() {
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            let newId = frontmostApp.bundleIdentifier ?? ""
            // 仅在 ID 确实发生变化时才更新，减少不必要的 UI 刷新
            if self.frontmostBundleId != newId {
                DispatchQueue.main.async {
                    self.frontmostBundleId = newId
                }
            }
        }
    }
}
