import Foundation

public enum APIKey {
    public struct Blank: Error, CustomStringConvertible {
        public var description: String { "the key is empty" }
    }

    /// Keeps the key for the app, readable only by you (0600), in ~/.config/halfsay.
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
    public static let file = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".config/halfsay/api-key")

    /// TYPESAFE_API_KEY from the environment, else the key file: an app opened from Finder gets no shell environment.
    public static func load(environment: [String: String] = ProcessInfo.processInfo.environment, file: URL = file) -> String? {
        let fromEnvironment = environment["TYPESAFE_API_KEY"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !fromEnvironment.isEmpty { return fromEnvironment }
        let fromFile = (try? String(contentsOf: file, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""  // no file = no key
        return fromFile.isEmpty ? nil : fromFile
    }
}
