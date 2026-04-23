import Foundation
import Cocoa

func dumpWindows() {
    let options: CGWindowListOption = [.optionAll, .excludeDesktopElements]
    if let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] {
        print("Total windows found: \(windowList.count)")
        for (index, window) in windowList.enumerated() {
            let name = window[kCGWindowName as String] as? String ?? "NO NAME"
            let ownerName = window[kCGWindowOwnerName as String] as? String ?? "UNKNOWN OWNER"
            let layer = window[kCGWindowLayer as String] as? Int ?? -1
            let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
            
            print("[\(index)] Owner: \(ownerName) | Name: \(name) | Layer: \(layer) | Bounds: \(bounds)")
        }
    }
}
dumpWindows()
