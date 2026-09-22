// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "halfsaid",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "HalfsaidCore"),
        .executableTarget(name: "jev-probe", dependencies: ["HalfsaidCore"]),
        .testTarget(name: "HalfsaidCoreTests", dependencies: ["HalfsaidCore"]),
    ]
)
