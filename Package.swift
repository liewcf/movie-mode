// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MovieMode",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "FocusMonitorCore", targets: ["FocusMonitorCore"]),
        .executable(name: "MovieMode", targets: ["MovieMode"])
    ],
    targets: [
        .target(name: "FocusMonitorCore"),
        .executableTarget(
            name: "MovieMode",
            dependencies: ["FocusMonitorCore"]
        ),
        .testTarget(
            name: "FocusMonitorCoreTests",
            dependencies: ["FocusMonitorCore"]
        )
    ]
)
