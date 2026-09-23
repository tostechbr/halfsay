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

extension InstalledApps {
    /// Other names an app is spoken by: the one Finder shows ("Notes" is "Notas" on a Portuguese Mac).
    public static func aliases(for apps: [String: URL]) -> [String: [String]] {
        apps.reduce(into: [:]) { result, app in
            let shown = FileManager.default.displayName(atPath: app.value.path)
            let localized = shown.hasSuffix(".app") ? String(shown.dropLast(4)) : shown
            result[app.key] = localized == app.key ? [app.key] : [app.key, localized]
        }
    }
}
