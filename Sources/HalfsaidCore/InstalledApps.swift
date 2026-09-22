import Foundation

public enum InstalledApps {
    public static let folders = [
        "/Applications", "/Applications/Utilities",
        "/System/Applications", "/System/Applications/Utilities",
        NSHomeDirectory() + "/Applications",
    ]

    /// App names Jev may choose from, e.g. "Notes", "Safari".
    public static func names(in folders: [String] = folders) -> [String] {
        let fm = FileManager.default
        let bundles = folders.flatMap { (try? fm.contentsOfDirectory(atPath: $0)) ?? [] }  // missing folder = no apps there
        return Set(bundles.filter { $0.hasSuffix(".app") }.map { String($0.dropLast(4)) }).sorted()
    }
}
