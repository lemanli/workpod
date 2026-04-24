import Cocoa
import SwiftUI
import Combine
import CoreGraphics
import CoreFoundation

struct ShortcutConfig: Codable {
    var cockpitSwitchKey: Int = 48 // Tab
    var cockpitSwitchModifiersRaw: UInt = (NSEvent.ModifierFlags.command.rawValue | NSEvent.ModifierFlags.option.rawValue)

    var windowSwitchKey: Int = 48 // Tab
    var windowSwitchModifiersRaw: UInt = NSEvent.ModifierFlags.option.rawValue

    var cockpitSwitchModifiers: NSEvent.ModifierFlags {
        get { NSEvent.ModifierFlags(rawValue: cockpitSwitchModifiersRaw) }
        set { cockpitSwitchModifiersRaw = newValue.rawValue }
    }

    var windowSwitchModifiers: NSEvent.ModifierFlags {
        get { NSEvent.ModifierFlags(rawValue: windowSwitchModifiersRaw) }
        set { windowSwitchModifiersRaw = newValue.rawValue }
    }
}

enum RecordingTarget {
    case none
    case cockpitSwitch
    case windowSwitch
}

class InputManager: ObservableObject {
    static let shared = InputManager()
    
    @Published var config = ShortcutConfig()
    @Published var recordingTarget: RecordingTarget = .none
    private let configKey = "WorkPodShortcutConfig"
    
    private var eventTap: CFMachPort?
    
    private init() {
        loadConfig()
        setupGlobalShortcuts()
    }
    
    private func loadConfig() {
        if let data = UserDefaults.standard.data(forKey: configKey),
           let decoded = try? JSONDecoder().decode(ShortcutConfig.self, from: data) {
            self.config = decoded
        }
    }
    
    func saveConfig(_ newConfig: ShortcutConfig) {
        self.config = newConfig
        if let encoded = try? JSONEncoder().encode(newConfig) {
            UserDefaults.standard.set(encoded, forKey: configKey)
        }
        setupGlobalShortcuts()
    }
    
    private func setupGlobalShortcuts() {
        // 移除旧的 Tap
        if let tap = eventTap {
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, CFRunLoopMode.defaultMode)
            eventTap = nil
        }
        
        let eventMask = (1 << CGEventType.keyDown.rawValue)
        
        // 创建 Event Tap 拦截所有 keyDown 事件
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: CGEventTapOptions(rawValue: 0)!,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passRetained(event) }
                let manager = Unmanaged<InputManager>.fromOpaque(refcon).takeUnretainedValue()
                
                return manager.handleEventTap(event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        if let tap = eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("✅ Event Tap created and added to Main RunLoop")
        } else {
            print("❌ Failed to create Event Tap. Please check Accessibility permissions.")
        }
    }
    
    private func handleEventTap(event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags.rawValue
        
        // 将 CGEventFlags 转换为 NSEvent.ModifierFlags (UInt64 -> UInt)
        let modifierFlags = NSEvent.ModifierFlags(rawValue: UInt(flags))
        let currentFlags = modifierFlags.intersection(.deviceIndependentFlagsMask)
        let baseFlags = currentFlags.subtracting(.shift)
        
        // 1. 处理快捷键录制
        if recordingTarget != .none {
            handleRecording(keyCode: keyCode, modifiers: baseFlags)
            return Unmanaged.passRetained(event)
        }
        
        // 2. 检查是否触发【工作舱切换】
        if keyCode == config.cockpitSwitchKey {
            if baseFlags == config.cockpitSwitchModifiers {
                let direction = currentFlags.contains(.shift) ? -1 : 1
                print("⌨️ [InputManager] Triggered Cockpit Switch: \(direction)")
                DispatchQueue.main.async {
                    CockpitManager.shared.switchCockpit(direction: direction)
                }
                return nil // 拦截事件，不传递给目标应用
            }
        }
        
        // 3. 检查是否触发【工作舱内窗口切换】
        if keyCode == config.windowSwitchKey {
            if baseFlags == config.windowSwitchModifiers {
                let direction = currentFlags.contains(.shift) ? -1 : 1
                print("⌨️ [InputManager] Triggered Member Switch: \(direction)")
                DispatchQueue.main.async {
                    CockpitManager.shared.switchMember(direction: direction)
                }
                return nil // 拦截事件，不传递给目标应用
            }
        }
        
        return Unmanaged.passRetained(event)
    }
    
    private func handleRecording(keyCode: Int, modifiers: NSEvent.ModifierFlags) {
        // 排除 Esc 键 (KeyCode 53)
        if keyCode == 53 {
            DispatchQueue.main.async {
                self.recordingTarget = .none
            }
            return
        }
        
        var newConfig = config
        switch recordingTarget {
        case .cockpitSwitch:
            newConfig.cockpitSwitchKey = keyCode
            newConfig.cockpitSwitchModifiers = modifiers
        case .windowSwitch:
            newConfig.windowSwitchKey = keyCode
            newConfig.windowSwitchModifiers = modifiers
        case .none:
            break
        }
        
        DispatchQueue.main.async {
            self.saveConfig(newConfig)
            self.recordingTarget = .none
        }
    }
    
    private func handleKeyDown(event: NSEvent) {
        // 逻辑已迁移至 handleEventTap
    }
    
    private func recordShortcut(event: NSEvent) {
        // 逻辑已迁移至 handleRecording
    }
}
