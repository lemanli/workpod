import Foundation
import AppKit
import SwiftUI
import Combine

struct AppInfo: Identifiable, Equatable {
    let id: String // Bundle ID
    let name: String
    let path: String
}

class AppManager: ObservableObject {
    static let shared = AppManager()
    
    @Published var installedApps: [AppInfo] = []
    
    init() {
        refreshApps()
    }
    
    func refreshApps() {
        var apps: [AppInfo] = []
        let searchPaths = ["/Applications", "/System/Applications"]
        
        for path in searchPaths {
            let fm = FileManager.default
            guard let contents = try? fm.contentsOfDirectory(atPath: path) else { continue }
            
            for item in contents where item.hasSuffix(".app") {
                let fullPath = "\(path)/\(item)"
                if let bundle = Bundle(path: fullPath),
                   let bundleId = bundle.bundleIdentifier,
                   let info = bundle.infoDictionary,
                   let name = info["CFBundleName"] as? String {
                    apps.append(AppInfo(id: bundleId, name: name, path: fullPath))
                }
            }
        }
        
        // Sort alphabetically and update the published property
        self.installedApps = apps.sorted { $0.name < $1.name }
    }
    
    func scanApps() -> [String: Any] {
        return ["apps": installedApps.map { ["name": $0.name, "id": $0.id] }]
    }
}
