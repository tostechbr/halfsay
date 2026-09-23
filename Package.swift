// swift-tools-version: 6.0
import Foundation
import PackageDescription

// The mic and speech recognition refuse to run without usage strings, so the CLI embeds an Info.plist.
let infoPlist = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Sources/halfsay/Info.plist").path

let package = Package(
    name: "halfsay",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "HalfsayCore"),
        .executableTarget(
            name: "halfsay",
            dependencies: ["HalfsayCore"],
            exclude: ["Info.plist", "AppIcon.icns"],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", infoPlist])]
        ),
        .executableTarget(name: "jev-probe", dependencies: ["HalfsayCore"]),
        .testTarget(name: "HalfsayCoreTests", dependencies: ["HalfsayCore"]),
    ]
)
