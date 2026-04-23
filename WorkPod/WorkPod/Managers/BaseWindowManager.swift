import AppKit
import SwiftUI
import Combine

class BaseWindowManager: ObservableObject {
    static let shared = BaseWindowManager()
    private var baseWindow: NSWindow?
    
    // The current visual theme color for the base
    @Published var baseThemeColor: NSColor = .windowBackgroundColor
    
    func setupBaseWindow(with color: NSColor) {
        self.baseThemeColor = color
        
        if let existingWindow = baseWindow {
            // Reuse existing window, just update the background color
            if let canvas = existingWindow.contentView as? BaseCanvasView {
                canvas.themeColor = color
            }
            existingWindow.orderFront(nil)
            return
        }
        
        let screenFrame = NSScreen.main?.visibleFrame ?? .zero
        
        // The base window is slightly smaller than the screen to create a "container" feel
        let padding: CGFloat = 40
        let rect = NSRect(
            x: padding, 
            y: padding + 40, // Offset for the TopBar
            width: screenFrame.width - (padding * 2), 
            height: screenFrame.height - (padding * 2) - 40
        )
        
        let window = NSWindow(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        
        window.level = NSWindow.Level(rawValue: NSWindow.Level.normal.rawValue - 1) 
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let baseView = BaseCanvasView(color: color)
        window.contentView = baseView
        
        window.orderFront(nil)
        self.baseWindow = window
        print("🖼️ [BaseWindow] Created new base window")
    }
    
    func closeBaseWindow() {
        // Instead of closing and destroying, just hide it to avoid deallocation crashes
        baseWindow?.orderOut(nil)
        print("🖼️ [BaseWindow] Hidden base window")
    }
    
    func getBaseFrame() -> CGRect {
        return baseWindow?.frame ?? .zero
    }
}

// Custom view to render the "well" effect
class BaseCanvasView: NSView {
    var themeColor: NSColor
    
    init(color: NSColor) {
        self.themeColor = color
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        let bounds = self.bounds
        
        // Draw the main background with a slight opacity
        themeColor.withAlphaComponent(0.4).setFill()
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 2), xRadius: 20, yRadius: 20)
        path.fill()
        
        // Draw a sophisticated inner-shadow/border to create the "inset" look
        let strokeColor = NSColor.black.withAlphaComponent(0.2)
        strokeColor.setStroke()
        let strokePath = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 20, yRadius: 20)
        strokePath.lineWidth = 3
        strokePath.stroke()
        
        // Top highlight to enhance 3D effect
        NSColor.white.withAlphaComponent(0.1).setFill()
        let highlightRect = NSRect(x: 0, y: bounds.height - 5, width: bounds.width, height: 5)
        NSBezierPath(roundedRect: highlightRect, xRadius: 5, yRadius: 5).fill()
    }
}
