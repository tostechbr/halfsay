// swift-tools-version: 6.0
import Foundation
import PackageDescription

// The mic and speech recognition refuse to run without usage strings, so the CLI embeds an Info.plist.
let infoPlist = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Sources/halfsaid/Info.plist").path

let package = Package(
    name: "halfsaid",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "HalfsaidCore"),
        .executableTarget(
            name: "halfsaid",
            dependencies: ["HalfsaidCore"],
            exclude: ["Info.plist"],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", infoPlist])]
        ),
        .executableTarget(name: "jev-probe", dependencies: ["HalfsaidCore"]),
        .testTarget(name: "HalfsaidCoreTests", dependencies: ["HalfsaidCore"]),
    ]
)
