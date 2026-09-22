import Foundation

/// A decided command, ready for an executor.
public enum Command: Equatable, Sendable {
    case openApp(String)
    case newItem
    case openURL(URL)
    case webSearch(String)
    case typeText(String)
}

extension Command: CustomStringConvertible {
    public var description: String {
        switch self {
        case .openApp(let app): "open \(app)"
        case .newItem: "new item"
        case .openURL(let url): "open \(url.absoluteString)"
        case .webSearch(let query): "search “\(query)”"
        case .typeText(let text): "type “\(text)”"
        }
    }
}

enum Site {
    /// Spoken site to URL: "x dot com" → https://x.com, "youtube" → https://youtube.com.
    static func url(from spoken: String) -> URL? {
        let host = spoken.lowercased()
            .replacingOccurrences(of: " dot ", with: ".")
            .replacingOccurrences(of: " ponto ", with: ".")
            .replacingOccurrences(of: " ", with: "")
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        let valid = !host.isEmpty && labels.allSatisfy { label in
            !label.isEmpty && label.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-") }
        }
        guard valid else { return nil }
        return URL(string: "https://" + (labels.count > 1 ? host : host + ".com"))
    }
}
