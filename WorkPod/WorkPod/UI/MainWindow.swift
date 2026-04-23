import SwiftUI

struct MainWindow: View {
    @EnvironmentObject var cockpitManager: CockpitManager
    @State private var editingCockpit: Cockpit?
    
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                // Left side: Cockpit List
                VStack(alignment: .leading) {
                    HStack {
                        Text("WorkPod")
                            .font(.largeTitle)
                        Spacer()
                        Button(action: addCockpit) {
                            Image(systemName: "plus")
                        }
                    }
                    .padding()
                    
                    List(cockpitManager.cockpits) { cockpit in
                        Button(action: {
                            cockpitManager.activateCockpit(id: cockpit.id)
                        }) {
                            CockpitRow(cockpit: cockpit, activeId: cockpitManager.activeCockpitId)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button("编辑") {
                                editingCockpit = cockpit
                            }
                            Button("删除", role: .destructive) {
                                cockpitManager.removeCockpit(id: cockpit.id)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
                .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
                
                // Right side: Active Cockpit Control Panel
                if cockpitManager.activeCockpitId != nil {
                    Divider()
                    CockpitControlPanel()
                        .padding()
                }
            }
            .frame(minWidth: 650, minHeight: 400)
            
            if cockpitManager.isSwitching, let target = cockpitManager.switchingToCockpit {
                SwitchingOverlay(cockpit: target)
            }

            if cockpitManager.isLeavingCockpit {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        LeaveNoticeView()
                            .padding()
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(), value: cockpitManager.isLeavingCockpit)
            }
        }
       .sheet(item: $editingCockpit) { cockpit in
            CockpitEditorView(cockpit: cockpit)
        }
        .onAppear {
            // 延迟所有启动后的重量级初始化，确保主线程在 App 启动激活期间完全空闲
            // 这能彻底解决 AppleEvent activation suspension timed out 导致的界面冻结
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                WindowManager.shared.checkAccessibilityPermissions()
                WindowManager.shared.startMonitoring()
                print("🚀 Startup deferred tasks completed")
            }

            // 状态栏初始化进一步延迟，避免与窗口场景激活冲突
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                _ = StatusBarManager.shared
                print("StatusBarManager: Deferred initialization complete")
            }
        }
    }
    
    private func addCockpit() {
        let newCockpit = Cockpit(
            id: UUID().uuidString,
            name: "新工作舱",
            icon: nil,
            members: [],
            defaultMode: .normal,
            createdAt: Date(),
            updatedAt: Date()
        )
        cockpitManager.addCockpit(newCockpit)
    }
}

struct SwitchingOverlay: View {
    let cockpit: Cockpit
    
    var body: some View {
        ZStack {
            // 全屏遮罩，使用半透明深色背景，禁止点击穿透
            Color.black.opacity(0.6)
                .edgesIgnoringSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture { } // 拦截点击事件
            
            VStack(spacing: 24) {
                Image(systemName: cockpit.icon ?? "macwindow")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                    .symbolEffect(.bounce, options: .repeating)
                
                VStack(spacing: 8) {
                    Text("正在切换至")
                        .font(.title2)
                        .foregroundColor(.gray)
                    
                    Text(cockpit.name)
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // 进度指示器
                ProgressView()
                    .scaleEffect(1.5)
                    .padding(.vertical, 10)
                
                HStack {
                    ForEach(cockpit.members.prefix(3)) { member in
                        Text(member.name)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(4)
                            .foregroundColor(.white)
                    }
                    if cockpit.members.count > 3 {
                        Text("...").foregroundColor(.white)
                    }
                }
                .padding(.top, 10)
            }
            .padding(60)
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 30, x: 0, y: 15)
            )
            .transition(.scale.combined(with: .opacity))
        }
    }
}

struct CockpitRow: View {
    let cockpit: Cockpit
    let activeId: String?
    
    var body: some View {
        HStack {
            Image(systemName: cockpit.icon ?? "macwindow")
                .font(.title)
                .foregroundColor(cockpit.id == activeId ? .blue : .secondary)
            
            VStack(alignment: .leading) {
                Text(cockpit.name)
                    .font(.headline)
                    .foregroundColor(cockpit.id == activeId ? .primary : .primary.opacity(0.7))
                Text("\(cockpit.members.count) 个成员")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if cockpit.id == activeId {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(cockpit.id == activeId ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
}
