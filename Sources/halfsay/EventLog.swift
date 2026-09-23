import Foundation

/// Opt-in local trace (`--log`): one JSON object per line in ~/Library/Logs/halfsay, never sent anywhere.
/// It holds everything the mic heard, side conversations included.
@MainActor
final class EventLog {
    let url: URL
    private let file: FileHandle
    private let started = ContinuousClock.now

    init() throws {
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/halfsay")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
        url = folder.appendingPathComponent("\(stamp).jsonl")
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else { throw CocoaError(.fileWriteUnknown) }
        file = try FileHandle(forWritingTo: url)
    }

    /// `t` is seconds since start; nil fields are left out.
    func write(_ event: String, _ fields: [String: Any?] = [:]) {
        var line: [String: Any] = ["event": event, "t": (ContinuousClock.now - started).seconds]
        for (key, value) in fields {
            if let value { line[key] = value }
        }
        do {
            let json = try JSONSerialization.data(withJSONObject: tidy(line), options: [.sortedKeys, .withoutEscapingSlashes])
            try file.write(contentsOf: json + Data("\n".utf8))
        } catch {
            out("⚠︎ log: \(error)\n")
        }
    }
}

/// 0.43 instead of 0.42999999999999999: JSONSerialization prints every digit of a Double.
private func tidy(_ value: Any) -> Any {
    switch value {
    case let number as Double: NSDecimalNumber(string: String(format: "%.3f", number))
    case let list as [Any]: list.map(tidy)
    case let object as [String: Any]: object.mapValues(tidy)
    default: value
    }
}
