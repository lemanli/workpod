import Foundation
import AppKit
import Combine

class CockpitManager: ObservableObject {
    static let shared = CockpitManager()
    @Published var cockpits: [Cockpit] = []
    @Published var activeCockpitId: String?
    @Published var isActivating = false
    @Published var isSwitching = false
    @Published var switchingToCockpit: Cockpit?
    @Published var isLeavingCockpit = false
    
    private let storageKey = "WorkPodCockpits"
    private let windowManager = WindowManager.shared
    
    init() {
        loadCockpits()
        ensureDefaultCockpit()
        setupApplicationObserver()
    }

    private func ensureDefaultCockpit() {
        if let activeId = activeCockpitId, cockpit(with: activeId) != nil {
            return
        }

        if !cockpits.isEmpty {
            activeCockpitId = cockpits.first?.id
            print("🎯 Defaulting to existing cockpit: \(activeCockpitId ?? "none")")
        } else {
            // Create a truly default cockpit if none exist
            let defaultCockpit = Cockpit(
                id: UUID().uuidString,
                name: "默认工作舱",
                icon: "macwindow",
                members: [],
                defaultMode: .normal,
                createdAt: Date(),
                updatedAt: Date()
            )
            addCockpit(defaultCockpit)
            activeCockpitId = defaultCockpit.id
            print("🆕 Created and activated default cockpit")
        }
    }
    
    private func setupApplicationObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let app = notification.userInfo?["NSWorkspaceApplicationUserInfoKey"] as? NSRunningApplication else { return }
            
            self.handleAppActivation(app: app)
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let app = notification.userInfo?["NSWorkspaceApplicationUserInfoKey"] as? NSRunningApplication else { return }
            
            self.handleAppTermination(app: app)
        }
    }
    
    private func handleAppActivation(app: NSRunningApplication) {
        guard let activeId = activeCockpitId,
              let cockpit = cockpit(with: activeId) else { return }
        
        let bundleId = app.bundleIdentifier ?? ""
        let isMember = cockpit.members.contains(where: { $0.bundleId == bundleId })
        
        if !isMember {
            print("⚠️ User left the cockpit: \\(cockpit.name) -> \\(app.localizedName ?? bundleId)")
            self.triggerLeaveNotice(app: app)
        }
    }

    private func handleAppTermination(app: NSRunningApplication) {
        guard let activeId = activeCockpitId,
              var cockpit = cockpit(with: activeId) else { return }
        
        let bundleId = app.bundleIdentifier ?? ""
        let originalCount = cockpit.members.count
        
        // 过滤掉已关闭的应用
        cockpit.members.removeAll { $0.bundleId == bundleId }
        
        if cockpit.members.count < originalCount {
            print("🗑️ 应用已关闭，从工作舱中移除：\(app.localizedName ?? bundleId)")
            updateCockpit(cockpit)
        }
    }

    private func triggerLeaveNotice(app: NSRunningApplication) {
        // We will implement the actual UI notification in the next step
        // For now, let's just update a published state that the UI can observe
        self.isLeavingCockpit = true
        
        // Auto-hide notice after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.isLeavingCockpit = false
        }
    }
    
    func loadCockpits() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            cockpits = []
            return
        }
        
        do {
            cockpits = try JSONDecoder().decode([Cockpit].self, from: data)
        } catch {
            print("❌ 加载工作舱配置失败：\(error)")
            cockpits = []
        }
    }
    
    func saveCockpits() {
        do {
            let data = try JSONEncoder().encode(cockpits)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("❌ 保存工作舱配置失败：\(error)")
        }
    }
    
    func addCockpit(_ cockpit: Cockpit) {
        cockpits.append(cockpit)
        saveCockpits()
    }
    
    func removeCockpit(id: String) {
        cockpits.removeAll { $0.id == id }
        saveCockpits()
        
        // 如果删除的是当前激活的工作舱，清除激活状态
        if activeCockpitId == id {
            activeCockpitId = nil
        }
    }
    
    func updateCockpit(_ cockpit: Cockpit) {
        if let index = cockpits.firstIndex(where: { $0.id == cockpit.id }) {
            cockpits[index] = cockpit
            saveCockpits()
        }
    }
    
    func deactivateCockpit(id: String, clearActiveId: Bool = true) {
        print("💤 Deactivating cockpit: \(id)")
        if clearActiveId && activeCockpitId == id {
            activeCockpitId = nil
        }
        BaseWindowManager.shared.closeBaseWindow()
        TopBarManager.shared.setVisible(false)
    }
    
    func cockpit(with id: String) -> Cockpit? {
        return cockpits.first { $0.id == id }
    }
    
    private var currentActivationTask: Task<Void, Never>?
    var activationToken = 0
    private var lastActivationTime: Date = .distantPast
    private var lastActivationId: String?
    
    @MainActor
    func activateCockpit(id: String) {
        print("🔍 activateCockpit called for \(id). Call stack: \(Thread.callStackSymbols.joined(separator: "\n"))")
        
        // 防抖：同一工作舱在 0.5 秒内不能重复激活
        if id == lastActivationId && Date().timeIntervalSince(lastActivationTime) < 0.5 {
            print("🛑 Throttling activation for \(id) - too frequent")
            return
        }
        lastActivationTime = Date()
        lastActivationId = id
        
        guard let cockpit = cockpit(with: id) else {
            print("❌ 工作舱不存在：\(id)")
            return
        }
        
        if activeCockpitId == id { return }
        
        // 1. 增加 Token，使之前的所有任务失效
        activationToken += 1
        let myToken = activationToken
        windowManager.updateToken(myToken)
        print("🎫 Requesting activation for: \(cockpit.name) (Token: \(myToken))")
        
        // 2. 立即更新 UI 状态
        self.switchingToCockpit = cockpit
        self.isSwitching = true
        
        // 3. 取消之前的任务
        currentActivationTask?.cancel()
        
        currentActivationTask = Task {
            // 极短延迟，确保 SwiftUI 状态同步
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
            
            if Task.isCancelled { return }
            
            await performActivation(id: id, token: myToken)
        }
    }
    
    @MainActor
    private func performActivation(id: String, token: Int) async {
        guard let cockpit = cockpit(with: id) else { return }
        
        // 锁定激活状态
        isActivating = true
        print("🚀 Starting activation process for: \(cockpit.name) (Token: \(token))")
        
        if let currentActiveId = activeCockpitId, currentActiveId != id {
            BaseWindowManager.shared.closeBaseWindow()
        }
        
        activeCockpitId = id
        TopBarManager.shared.setVisible(true)
        
        // 顺序启动应用
        for member in cockpit.members {
            if Task.isCancelled { break }
            launchApp(bundleId: member.bundleId, config: member.launchConfig)
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
        }
        
        // 关键：在执行耗时状态应用前检查 Token
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        if token != activationToken {
            print("🛑 Token mismatch (Current: \(activationToken), Mine: \(token)). Aborting activation.")
            // 注意：这里不设置 isActivating = false，因为新任务将接管
            return 
        }
        
        if Task.isCancelled { 
            if token == activationToken {
                isActivating = false 
                isSwitching = false
                switchingToCockpit = nil
            }
            return 
        }
        
        print("📐 Now applying cockpit state for: \(cockpit.name) (Token: \(token))")
        await applyCockpitState(cockpit, token: token)
        
        // 最终检查：只有最新的任务才能解锁状态
        if token == activationToken {
            self.isActivating = false 
            self.isSwitching = false
            self.switchingToCockpit = nil
            print("✅ Activation process completed (Token: \(token))")
        } else {
            print("🏁 Task finished but superseded by newer token (Token: \(token))")
        }
    }
    
    private func applyCockpitState(_ cockpit: Cockpit, token: Int) async {
        print("📐 Applying cockpit state for: \(cockpit.name) (Token: \(token))")
        
        // 1. Setup the visual base (Canvas)
        let baseColor = NSColor.windowBackgroundColor
        await MainActor.run {
            BaseWindowManager.shared.setupBaseWindow(with: baseColor)
        }
        
        let baseFrame = await MainActor.run { BaseWindowManager.shared.getBaseFrame() }
        
        // 2. Restore members and force them into the base frame
        for member in cockpit.members {
            let savedLayout = member.layout
            
            if cockpit.defaultMode == .pseudoFullscreen && member.isPrimary {
                // 直接调用，内部已处理异步
                windowManager.setPseudoFullscreen(for: member.bundleId, token: token)
            } else {
                var constrainedLayout = savedLayout
                
                if constrainedLayout.x < baseFrame.origin.x {
                    constrainedLayout.x = baseFrame.origin.x + 20
                }
                if constrainedLayout.y < baseFrame.origin.y {
                    constrainedLayout.y = baseFrame.origin.y + 20
                }
                if constrainedLayout.width > baseFrame.width - 40 {
                    constrainedLayout.width = baseFrame.width - 40
                }
                if constrainedLayout.height > baseFrame.height - 40 {
                    constrainedLayout.height = baseFrame.height - 40
                }
                
                // 关键：直接调用，不再使用 await MainActor.run
                // restoreLayout 内部已移至后台队列
                windowManager.restoreLayout(constrainedLayout, for: member.bundleId, token: token)
                try? await Task.sleep(nanoseconds: 50_000_000) // 间隔缩短至 0.05s
            }
        }
        
        // 3. 最终激活：仅对主成员执行一次强力激活，确保工作舱聚焦
        if let primaryMember = cockpit.members.first(where: { $0.isPrimary }) {
            print("🎯 Final focus on primary member: \(primaryMember.name)")
            windowManager.bringToFront(bundleId: primaryMember.bundleId, token: token)
        } else if let firstMember = cockpit.members.first {
            print("🎯 Final focus on first member: \(firstMember.name)")
            windowManager.bringToFront(bundleId: firstMember.bundleId, token: token)
        }
    }
    
    func switchMember(direction: Int) {
        guard let activeId = activeCockpitId,
              let cockpit = cockpit(with: activeId) else {
            print("❌ No active cockpit to switch members")
            return
        }
        
        let members = cockpit.members
        guard !members.isEmpty else { return }
        
        let currentFrontmostBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        
        // 🚀 修复：如果当前应用不是成员，将其视为在成员列表之前 (index -1)，
        // 这样 direction = 1 时会正确进入 members[0]。
        let currentIndex: Int
        if let foundIndex = members.firstIndex(where: { $0.bundleId == currentFrontmostBundleId }) {
            currentIndex = foundIndex
        } else {
            currentIndex = -1
        }
        
        var nextIndex = currentIndex + direction
        if nextIndex < 0 { nextIndex = members.count - 1 }
        if nextIndex >= members.count { nextIndex = 0 }
        
        let nextMember = members[nextIndex]
        print("🔄 Switching to next member: \(nextMember.name) [\(nextMember.bundleId)]")
        
        // 增加 Token 确保 AX 操作的唯一性和顺序性
        activationToken += 1
        windowManager.updateToken(activationToken)
        windowManager.bringToFront(bundleId: nextMember.bundleId, token: activationToken)
    }

    func switchCockpit(direction: Int) {
        guard !cockpits.isEmpty else { return }
        
        let currentIndex = cockpits.firstIndex(where: { $0.id == activeCockpitId }) ?? 0
        var nextIndex = currentIndex + direction
        if nextIndex < 0 { nextIndex = cockpits.count - 1 }
        if nextIndex >= cockpits.count { nextIndex = 0 }
        
        let nextCockpit = cockpits[nextIndex]
        print("🔄 Switching to next cockpit: \(nextCockpit.name)")
        activateCockpit(id: nextCockpit.id)
    }
    
    private func launchApp(bundleId: String, config: LaunchConfig) {
        // 检查应用是否已经在运行
        if NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == bundleId }) {
            // ⚠️ 重要：不再在这里调用 activate()。
            // 频繁的激活调用会导致 AppleEvent activation suspension timed out。
            // 激活将由 performActivation 在最后阶段仅对主成员执行一次。
            print("    → 应用已在运行，保持后台状态")
            return
        }
        
        // 启动应用
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            print("    → 找不到应用的 URL: \(bundleId)")
            return
        }
        
        NSWorkspace.shared.openApplication(
            at: url,
            configuration: NSWorkspace.OpenConfiguration(),
            completionHandler: { (app, error) in
                if let error = error {
                    print("    → 应用启动失败: \(error)")
                } else {
                    print("    → 应用启动成功")
                }
            })
    }
    
    private func restoreWindowLayout(for cockpit: Cockpit) {
        print("📐 恢复窗口布局：\(cockpit.name)")
        
        windowManager.updateToken(activationToken)
        for member in cockpit.members {
            windowManager.restoreLayout(member.layout, for: member.bundleId, token: activationToken)
        }
    }
}
