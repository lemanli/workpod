import AppKit
import SwiftUI
import Combine

class TopBarManager: ObservableObject {
    static let shared = TopBarManager()
    private var window: NSWindow?
    
    func setupTopBar() {
        // If window already exists, just update position
        if window != nil {
            updatePosition()
            return
        }

        let screenFrame = NSScreen.main?.frame ?? .zero
        let width: CGFloat = 600
        let height: CGFloat = 40
        let x = (screenFrame.width - width) / 2
        let y = screenFrame.height - height - 10
        
        let window = NSWindow(
            contentRect: NSRect(x: x, y: y, width: width, height: height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .mainMenu + 1
        window.ignoresMouseEvents = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        let contentView = NSHostingController(rootView: TopBarView().environmentObject(CockpitManager.shared))
        window.contentView = contentView.view
        window.orderFront(nil)
        self.window = window
    }

    func setVisible(_ visible: Bool) {
        if visible {
            window?.orderFront(nil)
        } else {
            window?.orderOut(nil)
        }
    }
    
    func updatePosition() {
        guard let window = window else { return }
        let screenFrame = NSScreen.main?.frame ?? .zero
        let x = (screenFrame.width - window.frame.width) / 2
        let y = screenFrame.height - window.frame.height - 10
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
