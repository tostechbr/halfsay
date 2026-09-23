import Foundation

extension Action {
    /// Short label for the floating bar.
    public var label: String {
        switch self {
        case .openApp: "open app"
        case .newItem: "new item"
        case .openURL: "open site"
        case .webSearch: "search"
        case .typeText: "type text"
        case .none: "not yet"
        }
    }
}

public struct ActionScore: Equatable, Sendable {
    public let action: Action
    public let probability: Double
}

extension Decision {
    /// The `count` likeliest actions, most likely first; ties by name so the bar never flickers.
    public func top(_ count: Int) -> [ActionScore] {
        actionProbabilities
            .map { ActionScore(action: $0.key, probability: $0.value) }
            .sorted { ($0.probability, $1.action.rawValue) > ($1.probability, $0.action.rawValue) }
            .prefix(count)
            .map { $0 }
    }
}

/// `seconds` > 0: the command fired that long before the last word.
public func describeLead(_ seconds: Double) -> String {
    seconds > 0 ? String(format: "%.2f s before you finished", seconds) : String(format: "%.2f s after you stopped", -seconds)
}

public struct SpokenWord: Equatable, Sendable {
    public let text: String
    public let used: Bool
}

public enum Transcript {
    /// The last `limit` words, marking the ones already turned into commands.
    public static func words(_ text: String, consumed: Int, limit: Int = 10) -> [SpokenWord] {
        text.split(whereSeparator: \.isWhitespace).enumerated()
            .map { SpokenWord(text: String($0.element), used: $0.offset < consumed) }
            .suffix(limit)
    }
}

public enum APIKey {
    public struct Blank: Error, CustomStringConvertible {
        public var description: String { "the key is empty" }
    }

    /// Keeps the key for the app, readable only by you (0600), in ~/.config/halfsaid.
    public static func save(_ key: String, to file: URL = file) throws {
        let key = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { throw Blank() }
        let fm = FileManager.default
        try fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard fm.createFile(atPath: file.path, contents: Data((key + "\n").utf8), attributes: [.posixPermissions: 0o600]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)  // also when it replaced an older key
    }
    public static let file = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/halfsaid/api-key")

    /// TYPESAFE_API_KEY from the environment, else the key file: an app opened from Finder gets no shell environment.
    public static func load(environment: [String: String] = ProcessInfo.processInfo.environment, file: URL = file) -> String? {
        let fromEnvironment = environment["TYPESAFE_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fromEnvironment.isEmpty { return fromEnvironment }
        let fromFile = (try? String(contentsOf: file, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""  // no file = no key
        return fromFile.isEmpty ? nil : fromFile
    }
}
