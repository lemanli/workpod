// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "WorkPod",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "WorkPod", targets: ["WorkPod"])],
    targets: [
        .executableTarget(
            name: "WorkPod",
            dependencies: [],
            path: "Sources"
        )
    ]
)
