// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Still",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "Still", targets: ["Still"])],
    targets: [
        .target(name: "StillCore"),
        .executableTarget(name: "Still", dependencies: ["StillCore"]),
        .executableTarget(name: "CoreChecks", dependencies: ["StillCore"], path: "Tests/StillCoreTests")
    ]
)
