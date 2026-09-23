// swift-tools-version: 6.0
import Foundation
import PackageDescription

// The mic and speech recognition refuse to run without usage strings, so the CLI embeds an Info.plist.
let infoPlist = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Sources/partway/Info.plist").path

let package = Package(
    name: "partway",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "PartwayCore"),
        .executableTarget(
            name: "partway",
            dependencies: ["PartwayCore"],
            exclude: ["Info.plist", "AppIcon.icns"],
            linkerSettings: [.unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT", "-Xlinker", "__info_plist", "-Xlinker", infoPlist])]
        ),
        .executableTarget(name: "jev-probe", dependencies: ["PartwayCore"]),
        .testTarget(name: "PartwayCoreTests", dependencies: ["PartwayCore"]),
    ]
)
