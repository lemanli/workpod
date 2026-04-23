import AppKit
import SwiftUI
import Combine

class StatusBarManager: ObservableObject {
    static let shared = StatusBarManager()
    
    private var statusItem: NSStatusItem?
    private var menu = NSMenu()
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupStatusItem()
        setupObservers()
    }
    
    private func setupStatusItem() {
        DispatchQueue.main.async { [weak self] in
            print("StatusBarManager: Attempting to setup status item on main thread...")
            self?.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            
            guard let item = self?.statusItem else {
                print("StatusBarManager: Critical Error - Could not create NSStatusItem")
                return
            }
            
            if let button = item.button {
                print("StatusBarManager: Status bar button found. Configuring...")
                
                // 1. 设置文字 Fallback，确保绝对可见
                button.title = "WP"
                
                // 2. 设置通用图标 (star 是最稳的)
                if let image = NSImage(systemSymbolName: "star.fill", accessibilityDescription: "WorkPod") {
                    button.image = image
                    print("StatusBarManager: Icon image set successfully")
                } else {
                    print("StatusBarManager: Warning - Icon image failed to load, relying on text title")
                }
                
                button.action = #selector(StatusBarManager.toggleMenu)
                button.target = self
                
                // 强制立即刷新一次菜单内容
                self?.refreshMenu()
            } else {
                print("StatusBarManager: Error - Status item has no button")
            }
        }
    }
    
    @objc private func toggleMenu() {
        refreshMenu()
        // In macOS, setting statusItem.menu automatically handles the popup when the button is clicked.
        print("StatusBar: Menu updated and displayed")
    }
    
    private func applyMenu() {
        statusItem?.menu = menu
    }
    
    private func setupObservers() {
        CockpitManager.shared.$activeCockpitId
            .sink { [weak self] _ in
                // 只有在非激活状态下才刷新菜单，避免在场景转换期间触碰 NSStatusItem
                if !CockpitManager.shared.isActivating {
                    self?.refreshMenu()
                }
            }
            .store(in: &cancellables)

        CockpitManager.shared.$isActivating
            .filter { $0 == false }
            .sink { [weak self] _ in
                self?.refreshMenu()
            }
            .store(in: &cancellables)
    }
    
    private var refreshWorkItem: DispatchWorkItem?
    
    func refreshMenu() {
        // 1. 绝对禁止在激活期间刷新菜单，防止触发 FBSScene 错误
        if CockpitManager.shared.isActivating {
            print("StatusBarManager: Skipping refresh during activation")
            return
        }
        
        // 取消之前的刷新请求，实现简单的防抖 (Debounce)
        refreshWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            self.menu.removeAllItems()
            
            if let activeId = CockpitManager.shared.activeCockpitId,
               let cockpit = CockpitManager.shared.cockpit(with: activeId) {
                
                // 场景 A: 有活跃工作舱 -> 显示该舱内的应用列表
                let headerItem = NSMenuItem(title: "当前舱: \(cockpit.name)", action: nil, keyEquivalent: "")
                headerItem.attributedTitle = NSAttributedString(string: "Current: \(cockpit.name)", attributes: [
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .font: NSFont.systemFont(ofSize: 11)
                ])
                headerItem.isEnabled = false
                self.menu.addItem(headerItem)
                
                self.menu.addItem(NSMenuItem.separator())
                
                for member in cockpit.members {
                    let appName = WindowManager.shared.getAppName(for: member.bundleId)
                    let item = NSMenuItem(title: appName, action: #selector(self.menuItemClicked(_:)), keyEquivalent: "")
                    item.representedObject = member.bundleId
                    item.target = self
                    self.menu.addItem(item)
                }
                
                self.menu.addItem(NSMenuItem.separator())
                
                let switchCockpitItem = NSMenuItem(title: "切换工作舱...", action: #selector(self.showCockpitList), keyEquivalent: "s")
                switchCockpitItem.target = self
                self.menu.addItem(switchCockpitItem)
                
            } else {
                // 场景 B: 没有活跃工作舱 -> 显示所有可用工作舱列表
                let headerItem = NSMenuItem(title: "请选择工作舱", action: nil, keyEquivalent: "")
                headerItem.attributedTitle = NSAttributedString(string: "Select a Cockpit", attributes: [
                    .foregroundColor: NSColor.secondaryLabelColor,
                    .font: NSFont.systemFont(ofSize: 11)
                ])
                headerItem.isEnabled = false
                self.menu.addItem(headerItem)
                
                let allCockpits = CockpitManager.shared.cockpits
                if allCockpits.isEmpty {
                    let emptyItem = NSMenuItem(title: "尚未创建工作舱", action: nil, keyEquivalent: "")
                    emptyItem.isEnabled = false
                    self.menu.addItem(emptyItem)
                } else {
                    for cockpit in allCockpits {
                        let item = NSMenuItem(title: cockpit.name, action: #selector(self.activateCockpitAction(_:)), keyEquivalent: "")
                        item.representedObject = cockpit.id
                        item.target = self
                        self.menu.addItem(item)
                    }
                }
            }
            
            self.applyMenu()
        }
        refreshWorkItem = workItem
        // 增加延迟到 0.3 秒，确保 UI 场景完全稳定后再刷新菜单
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
    
    @objc private func showCockpitList() {
        // 简单的实现：临时清除 activeId 并刷新菜单以显示列表
        CockpitManager.shared.activeCockpitId = nil
        refreshMenu()
    }
    
    @objc private func menuItemClicked(_ sender: NSMenuItem) {
        if let bundleId = sender.representedObject as? String {
            print("StatusBar: Switching to \(bundleId)")
            WindowManager.shared.bringToFront(bundleId: bundleId, token: CockpitManager.shared.activationToken)
        }
    }
    
    @objc private func activateCockpitAction(_ sender: NSMenuItem) {
        if let cockpitId = sender.representedObject as? String {
            print("StatusBar: Activating cockpit \\(cockpitId)")
            CockpitManager.shared.activateCockpit(id: cockpitId)
            refreshMenu()
        }
    }
}
