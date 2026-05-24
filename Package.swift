// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FocusMonitor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "FocusMonitorCore", targets: ["FocusMonitorCore"]),
        .executable(name: "FocusMonitor", targets: ["FocusMonitor"])
    ],
    targets: [
        .target(name: "FocusMonitorCore"),
        .executableTarget(
            name: "FocusMonitor",
            dependencies: ["FocusMonitorCore"]
        ),
        .testTarget(
            name: "FocusMonitorCoreTests",
            dependencies: ["FocusMonitorCore"]
        )
    ]
)
