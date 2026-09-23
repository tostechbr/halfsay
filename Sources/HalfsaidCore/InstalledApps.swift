import Foundation

public enum InstalledApps {
    public static let folders = [
        "/Applications", "/Applications/Utilities",
        "/System/Applications", "/System/Applications/Utilities",
        NSHomeDirectory() + "/Applications",
    ]

    /// App name → bundle, e.g. "Notes" → /System/Applications/Notes.app. Earlier folders win.
    public static func urls(in folders: [String] = folders) -> [String: URL] {
        let fm = FileManager.default
        let bundles = folders.flatMap { folder in
            ((try? fm.contentsOfDirectory(atPath: folder)) ?? [])  // missing folder = no apps there
                .filter { $0.hasSuffix(".app") }
                .map { (String($0.dropLast(4)), URL(fileURLWithPath: folder).appendingPathComponent($0)) }
        }
        return Dictionary(bundles, uniquingKeysWith: { first, _ in first })
    }

    /// App names Jev may choose from, e.g. "Notes", "Safari".
    public static func names(in folders: [String] = folders) -> [String] {
        urls(in: folders).keys.sorted()
    }
}
