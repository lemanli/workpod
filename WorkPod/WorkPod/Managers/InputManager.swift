import Cocoa
import SwiftUI
import Combine

class InputManager: ObservableObject {
    static let shared = InputManager()
    
    private init() {
        setupGlobalShortcuts()
    }
    
    private func setupGlobalShortcuts() {
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event: event)
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event: event)
            return event
        }
    }
    
    private func handleKeyDown(event: NSEvent) {
        guard event.modifierFlags.contains(.control) else { return }
        if event.keyCode == 123 {
            CockpitManager.shared.switchMember(direction: -1)
        } else if event.keyCode == 124 {
            CockpitManager.shared.switchMember(direction: 1)
        }
    }
}
