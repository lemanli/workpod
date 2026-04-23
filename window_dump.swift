import Foundation
import CoreGraphics

func dumpWindows() {
    let options: CGWindowListOption = [.optionAll]
    // Use the literal string for the exclude option if needed, 
    // but let's just dump everything to be safe.
    guard let windowList = CGWindowListCopyWindowInfo(options, 0) as? [[String: Any]] else {
        print("Failed to get window list")
        return
    }

    print("Total windows found: \(windowList.count)")
    print("--------------------------------------------------------------------------------")
    print(String(format: "%-10@ %-10@ %-10@ %-10@ %-20@ %-30@", "ID", "PID", "Layer", "Alpha", "Bounds", "Name"))
    print("--------------------------------------------------------------------------------")

    for info in windowList {
        let id = info["kCGWindowNumber"] as? Int ?? 0
        let pid = info["kCGWindowOwnerPID"] as? Int ?? 0
        let layer = info["kCGWindowLayer"] as? Int ?? 0
        let alpha = info["kCGWindowAlpha"] as? CGFloat ?? 0
        let name = info["kCGWindowName"] as? String ?? "N/A"
        
        if let bounds = info["kCGWindowBounds"] as? NSDictionary {
            let x = bounds["kCGWindowBoundsX"] as? CGFloat ?? 0
            let y = bounds["kCGWindowBoundsY"] as? CGFloat ?? 0
            let w = bounds["kCGWindowBoundsWidth"] as? CGFloat ?? 0
            let h = bounds["kCGWindowBoundsHeight"] as? CGFloat ?? 0
            let boundsStr = String(format: "%.1f,%.1f %.1fx%.1f", x, y, w, h)
            
            print(String(format: "%-10d %-10d %-10d %-10.2f %-20@ %-30@", id, pid, layer, alpha, boundsStr, name))
        }
    }
}

dumpWindows()
