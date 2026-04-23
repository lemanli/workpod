import Foundation

struct Cockpit: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var icon: String?
    var members: [Member]
    var defaultMode: CockpitMode
    var createdAt: Date
    var updatedAt: Date
}

enum CockpitMode: String, Codable {
    case normal
    case immersive
    case pseudoFullscreen
}

struct Member: Identifiable, Codable, Equatable {
    let id: String
    var bundleId: String
    var name: String
    var launchConfig: LaunchConfig
    var layout: WindowLayout
    var isPrimary: Bool
}

struct LaunchConfig: Codable, Equatable {
    var urls: [String]?
    var directory: String?
    var profile: String?
}

struct WindowLayout: Codable, Equatable {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var displayId: String?
}
