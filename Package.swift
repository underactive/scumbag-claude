// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeTmpMonitor",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClaudeTmpMonitor",
            path: "Sources/ClaudeTmpMonitor",
            exclude: ["Resources"]
        )
    ]
)
