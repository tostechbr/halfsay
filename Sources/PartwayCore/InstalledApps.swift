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
    /// Other names an app is spoken by: its name in each of your languages ("Notes" is "Notas" in Portuguese).
    /// Asked language by language because partway ships no translations, so Finder's lookup answers it in English.
    public static func aliases(for apps: [String: URL], languages: [String] = Locale.preferredLanguages) -> [String: [String]] {
        apps.reduce(into: [:]) { result, app in
            result[app.key] = spokenNames(of: app.value, in: languages).reduce(into: [app.key]) { names, name in
                if !names.contains(name) { names.append(name) }
            }
        }
    }

    /// ponytail: before macOS 15.4 only Finder's lookup, so English names and a chained command after "notas" can be lost.
    private static func spokenNames(of app: URL, in languages: [String]) -> [String] {
        if #available(macOS 15.4, *), let bundle = Bundle(url: app) {
            return languages.compactMap { name(of: bundle, in: $0) }
        }
        let shown = FileManager.default.displayName(atPath: app.path)
        return [shown.hasSuffix(".app") ? String(shown.dropLast(4)) : shown]
    }

    @available(macOS 15.4, *)
    private static func name(of bundle: Bundle, in language: String) -> String? {
        for key in ["CFBundleDisplayName", "CFBundleName"] {
            let name = bundle.localizedString(forKey: key, value: nil, table: "InfoPlist",
                                              localizations: [Locale.Language(identifier: language)])
            if name != key { return name }  // a key with no translation comes back as itself
        }
        return nil
    }
}

extension InstalledApps {
    /// The installed apps among `openers`, e.g. the browsers when NSWorkspace lists the apps that open https links.
    public static func names(of openers: [URL], among apps: [String: URL]) -> Set<String> {
        let paths = Set(openers.map(\.standardizedFileURL.path))
        return Set(apps.filter { paths.contains($0.value.standardizedFileURL.path) }.keys)
    }
}
