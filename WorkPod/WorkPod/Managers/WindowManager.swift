import Foundation
import Cocoa
import AppKit
import Combine

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    
    @Published var windowList: [WindowInfo] = []
    
    private var refreshTimer: Timer?
    private let axQueue = DispatchQueue(label: "com.workpod.axqueue", qos: .userInitiated)
    
    // 跟踪当前的激活 Token，用于过滤过时的 AX 操作
    private var _currentToken: Int = 0
    private let tokenLock = NSLock()
    
    var currentToken: Int {
        get {
            tokenLock.lock()
            defer { tokenLock.unlock() }
            return _currentToken
        }
        set {
            tokenLock.lock()
            _currentToken = newValue
            tokenLock.unlock()
        }
    }
    
    init(refreshInterval: TimeInterval = 1.0) {
        // Timer no longer started in init to avoid blocking app startup
    }
    
    func updateToken(_ token: Int) {
        self.currentToken = token
    }

    func startMonitoring(interval: TimeInterval = 1.0) {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true) { [weak self] _ in
                DispatchQueue.global(qos: .utility).async {
                    self?.updateWindowList()
                }
            }
        print("📡 Window monitoring started")
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    // 内部助手方法：支持通过 Bundle ID 或 应用名称 查找运行中的应用
    private func findApp(with nameOrId: String) -> NSRunningApplication? {
        let runningApps = NSWorkspace.shared.runningApplications
        if let app = runningApps.first(where: { $0.bundleIdentifier == nameOrId }) {
            return app
        }
        if let app = runningApps.first(where: { $0.localizedName == nameOrId }) {
            return app
        }
        return nil
    }
    
    func getAppName(for bundleId: String) -> String {
        if let app = findApp(with: bundleId) {
            return app.localizedName ?? bundleId
        }
        return bundleId
    }
    
    func checkAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        if !accessEnabled {
            print("⚠️ 辅助功能权限未开启，请在系统设置中允许。")
        } else {
            print("✅ 辅助功能权限已开启。")
        }
    }
    
    func updateWindowList() {
        let windows = getAllWindows()
        DispatchQueue.main.async {
            self.windowList = windows
            // 在更新基础列表后，异步增强标题信息（获取标签页）
            self.enrichWindowTitles()
        }
    }
    
    private func enrichWindowTitles() {
        let currentWindows = self.windowList
        guard !currentWindows.isEmpty else { return }
        
        axQueue.async {
            var updatedWindows = currentWindows
            
            for i in 0..<updatedWindows.count {
                let info = updatedWindows[i]
                let pid = info.ownerId
                
                let axApp = AXUIElementCreateApplication(pid_t(pid))
                var windowsRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef) == .success {
                    if let axWindows = windowsRef as? [AXUIElement] {
                        // 🚀 核心修复：使用 Bounds (位置和大小) 进行匹配，而不是依赖不稳定的标题
                        let matchedWindow = axWindows.first { axWin in
                            guard let axBounds = self.getAXBounds(axWin) else { return false }
                            
                            // 允许 2 像素的误差，因为 CG 和 AX 的坐标系可能微小不一致
                            let dx = abs(axBounds.origin.x - info.bounds.origin.x)
                            let dy = abs(axBounds.origin.y - info.bounds.origin.y)
                            let dw = abs(axBounds.size.width - info.bounds.width)
                            let dh = abs(axBounds.size.height - info.bounds.height)
                            
                            return dx < 2 && dy < 2 && dw < 2 && dh < 2
                        }
                        
                        if let window = matchedWindow {
                            // 1. 获取 AX 窗口的真实标题 (解决 Ghostty 等自定义标题问题)
                            let axTitle = self.getAXAttribute(window, kAXTitleAttribute as String) ?? ""
                            
                            // 2. 尝试获取标签页
                            let tabs = self.fetchTabTitles(for: window)
                            
                            if !tabs.isEmpty {
                                let tabsString = tabs.joined(separator: ", ")
                                updatedWindows[i].combinedTitle = "\(info.ownerName): [\(tabsString)]"
                            } else if !axTitle.isEmpty {
                                updatedWindows[i].combinedTitle = "\(info.ownerName) - \(axTitle)"
                            }
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.windowList = updatedWindows
            }
        }
    }
    
    private func fetchTabTitles(for window: AXUIElement) -> [String] {
        var tabs: [String] = []
        
        // 1. 搜索直接子元素中的 Tab
        var childrenRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXChildrenAttribute as CFString, &childrenRef) == .success {
            if let children = childrenRef as? [AXUIElement] {
                for child in children {
                    if let title = self.getAXAttribute(child, kAXTitleAttribute as String) {
                        // 检查角色是否为 Tab 或包含 Tab 关键字
                        var roleRef: CFTypeRef?
                        if AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef) == .success {
                            let role = roleRef as? String ?? ""
                            if role == "AXTab" || role.contains("Tab") {
                                tabs.append(title)
                            }
                        }
                    }
                }
            }
        }
        
        // 2. 如果没找到，尝试深度搜索 (简单的一层递归)
        if tabs.isEmpty {
            // 很多应用将 Tab 放在一个专门的 TabBar 容器里
            var childrenRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXChildrenAttribute as CFString, &childrenRef) == .success {
                if let children = childrenRef as? [AXUIElement] {
                    for child in children {
                        var roleRef: CFTypeRef?
                        if AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef) == .success {
                            let role = roleRef as? String ?? ""
                            if role.contains("TabBar") || role.contains("Group") {
                                var subChildrenRef: CFTypeRef?
                                if AXUIElementCopyAttributeValue(child, kAXChildrenAttribute as CFString, &subChildrenRef) == .success {
                                    if let subChildren = subChildrenRef as? [AXUIElement] {
                                        for subChild in subChildren {
                                            if let title = self.getAXAttribute(subChild, kAXTitleAttribute as String) {
                                                tabs.append(title)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        return tabs
    }
    
    private func getAXAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
        var valueRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(element, attribute as CFString, &valueRef) == .success {
            return valueRef as? String
        }
        return nil
    }
    
    func getAllWindows() -> [WindowInfo] {
        var windows: [WindowInfo] = []
        let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
        
        // 获取屏幕主尺寸用于条状窗口判定
        let mainScreen = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let screenWidth = mainScreen.width
        let screenHeight = mainScreen.height
        
        if let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] {
            for window in windowList {
                let layer = window[kCGWindowLayer as String] as? Int ?? 0
                let ownerId = window[kCGWindowOwnerPID as String] as? Int ?? 0
                
                if ownerId == 0 { continue }
                
                if let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] {
                    let w = bounds["Width"] ?? 0
                    let h = bounds["Height"] ?? 0
                    
                    // 1. 基础尺寸过滤
                    if w <= 0 || h <= 0 { continue }
                    
                    // 2. 剔除极小窗口 (面积 < 40,000 或 宽/高 < 100)
                    if w * h < 40000 || w < 100 || h < 100 { continue }
                    
                    // 3. 剔除条状窗口 (极宽且极矮，或极窄且极高)
                    // 判定标准：高度 < 100 且 宽度覆盖屏幕 80% 以上
                    if (h < 100 && w > screenWidth * 0.8) || (w < 100 && h > screenHeight * 0.8) {
                        continue
                    }
                } else {
                    continue
                }

                if let alpha = window[kCGWindowAlpha as String] as? Double, alpha < 0.1 {
                    continue
                }

                if layer != 0 { continue }
                
                if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == ownerId }),
                   app.isHidden {
                    continue
                }

                let info = WindowInfo(from: window)
                windows.append(info)
            }
        }
        
        // 🚀 增强版去重逻辑：基于面积和空间关系的竞争
        let grouped = Dictionary(grouping: windows, by: { $0.ownerId })
        var filteredWindows: [WindowInfo] = []
        
        for (pid, appWindows) in grouped {
            if appWindows.count <= 1 {
                filteredWindows.append(contentsOf: appWindows)
                continue
            }
            
            // 按面积从大到小排序
            let sortedByArea = appWindows.sorted { 
                ($0.bounds.width * $0.bounds.height) > ($1.bounds.width * $1.bounds.height) 
            }
            
            var keptWindows: [WindowInfo] = []
            
            for candidate in sortedByArea {
                // 增强版子集判定
                let isSubset = keptWindows.contains { kept in
                    // 1. 近乎重复判定：如果坐标和尺寸极其接近 (误差 < 5px)
                    let isNearDuplicate = abs(candidate.bounds.origin.x - kept.bounds.origin.x) < 5 &&
                                          abs(candidate.bounds.origin.y - kept.bounds.origin.y) < 5 &&
                                          abs(candidate.bounds.width - kept.bounds.width) < 5 &&
                                          abs(candidate.bounds.height - kept.bounds.height) < 5
                    
                    if isNearDuplicate { return true }

                    // 2. 完全包含判定
                    let isContained = candidate.bounds.origin.x >= kept.bounds.origin.x - 1 &&
                                      candidate.bounds.origin.y >= kept.bounds.origin.y - 1 &&
                                      (candidate.bounds.origin.x + candidate.bounds.width) <= (kept.bounds.origin.x + kept.bounds.width) + 1 &&
                                      (candidate.bounds.origin.y + candidate.bounds.height) <= (kept.bounds.origin.y + kept.bounds.height) + 1
                    
                    if isContained { return true }
                    
                    // 3. 中心点距离判定：如果中心点距离极近且尺寸相仿
                    let candidateCenter = CGPoint(x: candidate.bounds.midX, y: candidate.bounds.midY)
                    let keptCenter = CGPoint(x: kept.bounds.midX, y: kept.bounds.midY)
                    let dist = hypot(candidateCenter.x - keptCenter.x, candidateCenter.y - keptCenter.y)
                    let sizeDiff = abs(candidate.bounds.width - kept.bounds.width) + abs(candidate.bounds.height - kept.bounds.height)
                    if dist < 20 && sizeDiff < 50 { return true }
                    
                    // 4. 动态面积重叠判定
                    let intersect = candidate.bounds.intersection(kept.bounds)
                    let intersectArea = intersect.width * intersect.height
                    let candidateArea = candidate.bounds.width * candidate.bounds.height
                    let keptArea = kept.bounds.width * kept.bounds.height
                    
                    // 如果大窗口面积是候选窗口的 2 倍以上，降低重叠阈值到 50%
                    let overlapThreshold = (keptArea > candidateArea * 2.0) ? 0.5 : 0.7
                    if intersectArea > candidateArea * overlapThreshold { return true }
                    
                    // 5. 标题权重判定：主窗口有标题，候选窗口无标题且有重叠
                    if !kept.title.isEmpty && candidate.title.isEmpty {
                        if intersectArea > 0 { return true }
                    }
                    
                    // 6. 同标题重叠判定：如果两个窗口标题完全一样且有显著重叠
                    if !candidate.title.isEmpty && candidate.title == kept.title {
                        if intersectArea > candidateArea * 0.5 { return true }
                    }
                    
                    return false
                }
                
                if !isSubset {
                    keptWindows.append(candidate)
                }
            }
            
            // 诊断：如果去重后依然有多个窗口，记录下来
            if keptWindows.count > 1 {
                print("⚠️ [WindowManager] PID \(pid) still has \(keptWindows.count) windows after deduplication:")
                for win in keptWindows {
                    print("   - ID: \(win.id), Title: '\(win.title)', Bounds: \(win.bounds)")
                }
            }
            
            filteredWindows.append(contentsOf: keptWindows)
        }
        
        return filteredWindows.sorted { $0.id < $1.id }
    }
    
    private func getAXBounds(_ element: AXUIElement) -> CGRect? {
        var positionRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        
        if AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionRef) == .success,
           AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success {
            
            let posValue = positionRef as! AXValue
            let sizeValue = sizeRef as! AXValue
            
            var point = CGPoint.zero
            var size = CGSize.zero
            if AXValueGetValue(posValue, .cgPoint, &point), AXValueGetValue(sizeValue, .cgSize, &size) {
                return CGRect(origin: point, size: size)
            }
        }
        return nil
    }
    
    func getWindows(for bundleId: String) -> [WindowInfo] {
        updateWindowList()
        return windowList.filter { $0.bundleId == bundleId }
    }
    
    func getFrontmostWindow(for bundleId: String) -> WindowInfo? {
        let appWindows = getWindows(for: bundleId)
        return appWindows.min(by: { $0.id < $1.id })
    }
    
    func saveLayout(for bundleId: String) -> WindowLayout? {
        guard let window = getFrontmostWindow(for: bundleId) else { return nil }
        return WindowLayout(
            x: window.bounds.origin.x,
            y: window.bounds.origin.y,
            width: window.bounds.width,
            height: window.bounds.height,
            displayId: nil
        )
    }
    
    func restoreLayout(_ layout: WindowLayout, for bundleId: String, token: Int) {
        guard let app = findApp(with: bundleId) else {
            print("❌ App not running: \(bundleId)")
            return
        }
        
        let pid = app.processIdentifier
        
        axQueue.async {
            if token != self.currentToken {
                print("🛑 AX restoreLayout obsolete (Token: \(token) != \(self.currentToken)). Skipping for \(bundleId)")
                return
            }
            
            print("🛠️ [AX] Starting restoreLayout for \(bundleId) (PID: \(pid))")
            let axApp = AXUIElementCreateApplication(pid)
            
            var windowsRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef)
            if result == .success {
                if let windows = windowsRef as? [AXUIElement], let window = windows.first {
                    var point = CGPoint(x: layout.x, y: layout.y)
                    if let posValue = AXValueCreate(AXValueType.cgPoint, &point) {
                        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)
                    }
                    var size = CGSize(width: layout.width, height: layout.height)
                    if let sizeValue = AXValueCreate(AXValueType.cgSize, &size) {
                        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeValue)
                    }
                    print("✅ [AX] Restored layout for \(bundleId)")
                }
            } else {
                print("❌ [AX] Failed to get AXWindows for \(bundleId) (Result: \(result.rawValue))")
            }
        }
    }
    
    func maximizeWindow(for bundleId: String, token: Int) {
        setPseudoFullscreen(for: bundleId, token: token)
    }
    
    func setPseudoFullscreen(for bundleId: String, token: Int) {
        bringToFront(bundleId: bundleId, token: token)
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        let layout = WindowLayout(
            x: screenFrame.origin.x,
            y: screenFrame.origin.y,
            width: screenFrame.width,
            height: screenFrame.height,
            displayId: nil
        )
        restoreLayout(layout, for: bundleId, token: token)
        print("📺 Set pseudo-fullscreen for \(bundleId)")
    }
    
    func bringToFront(bundleId: String, token: Int) {
        guard let app = findApp(with: bundleId) else {
            print("❌ App not found: \(bundleId)")
            return
        }
        
        // 移除此处的前台检查，因为在切换工作舱时，即使 App 已经在前台，
        // 我们可能仍需要通过 AX 确保特定的窗口被正确聚焦/取消最小化
        
        let pid = app.processIdentifier
        
        axQueue.async {
            if token != self.currentToken {
                print("🛑 AX bringToFront obsolete (Token: \(token) != \(self.currentToken)). Skipping for \(bundleId)")
                return
            }
            
            print("🚀 [AX] Starting background activation for \(bundleId) (PID: \(pid))")
            
            // 1. 基础激活
            app.activate(options: [])
            
            Thread.sleep(forTimeInterval: 0.1)
            
            // 2. 窗口级恢复与聚焦
            let axApp = AXUIElementCreateApplication(pid)
            
            var windowsRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windowsRef)
            if result == .success {
                if let windows = windowsRef as? [AXUIElement], let window = windows.first {
                    
                    // A. 检查并取消最小化
                    var minimizedRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedRef) == .success {
                        if let minimized = minimizedRef as? Bool, minimized == true {
                            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                            print("✅ [AX] Unminimized window for \(bundleId)")
                        }
                    }
                    
                    // B. 设置为 Main 窗口
                    AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, kCFBooleanTrue)
                    
                    // C. 强制前端化 (获取标题以确保窗口响应)
                    var titleRef: CFTypeRef?
                    if AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success {
                        let _ = titleRef as? String
                    }
                    
                    print("✅ [AX] Window-level focus completed for \(bundleId) (PID: \(pid))")
                }
            } else {
                print("⚠️ [AX] Could not find any AXWindows for \(bundleId) (Result: \(result.rawValue))")
            }
            
            DispatchQueue.main.async {
                print("🏁 [AX] Activation sequence finished for \(bundleId)")
            }
        }
    }
    
    func minimizeAllWindows(except bundleId: String?) {
        for app in NSWorkspace.shared.runningApplications {
            if app.bundleIdentifier != bundleId, !app.isHidden {
                app.hide()
            }
        }
    }
}

struct WindowInfo: Identifiable {
    let id: Int
    let title: String
    let bounds: CGRect
    let ownerId: Int
    let ownerName: String
    let bundleId: String?
    let layer: Int
    var combinedTitle: String? // 用于存储通过 AX 获取的合并标签标题
    
    var displayName: String {
        // 优先使用合并标题，如果没有，则使用 "应用名 - 窗口标题"
        if let combined = combinedTitle {
            return "\(combined) [ID: \(id)]"
        }
        let baseName = title.isEmpty ? "\(ownerName) 无名窗口" : "\(ownerName) - \(title)"
        return "\(baseName) [ID: \(id)]"
    }
    
    init(from dict: [String: Any]) {
        self.id = dict[kCGWindowNumber as String] as? Int ?? 0
        self.title = dict[kCGWindowName as String] as? String ?? ""
        self.layer = dict[kCGWindowLayer as String] as? Int ?? 0
        if let b = dict[kCGWindowBounds as String] as? [String: CGFloat] {
            self.bounds = CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0, width: b["Width"] ?? 0, height: b["Height"] ?? 0)
        } else {
            self.bounds = .zero
        }
        self.ownerId = dict[kCGWindowOwnerPID as String] as? Int ?? 0
        self.ownerName = dict[kCGWindowOwnerName as String] as? String ?? "Unknown"
        
        if let pid = dict[kCGWindowOwnerPID as String] as? Int,
           let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid }) {
            self.bundleId = app.bundleIdentifier
        } else {
            self.bundleId = dict[kCGWindowOwnerName as String] as? String
        }
    }
}
