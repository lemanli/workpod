import SwiftUI
import AppKit

@main
struct WorkPodApp: App {
    
    init() {
        // 确保应用在顶部菜单栏显示 (Regular 模式会显示应用菜单)
        NSApplication.shared.setActivationPolicy(.regular)
    }
    
    var body: some Scene {
        WindowGroup {
            MainWindow()
                .environmentObject(CockpitManager.shared)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("关于 WorkPod") {
                    // About logic
                }
                Button("退出 WorkPod") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            
            CommandMenu("工作舱") {
                Button("刷新状态") {
                    StatusBarManager.shared.refreshMenu()
                }
                .keyboardShortcut("r")
            }
        }
        
        Settings {
            SettingsView()
        }
    }
}
