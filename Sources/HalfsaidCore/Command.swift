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
    /// Spoken site to URL: "x dot com" → https://x.com, "meu site do LinkedIn" → https://linkedin.com.
    static func url(from spoken: String) -> URL? {
        let framing = Vocabulary.filler.union(Vocabulary.siteWords)
        let words = spoken.split(separator: " ").filter { !framing.contains(Vocabulary.normalized($0)) }
        // Several words and no "dot" is a topic ("receita de bolo"), not an address: the engine searches for it instead.
        let spelled = words.contains { ["dot", "ponto"].contains(Vocabulary.normalized($0)) || $0.contains(".") }
        guard words.count == 1 || spelled else { return nil }
        let host = words.joined(separator: " ")
            .lowercased()
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

extension Command {
    /// Where browser commands go.
    public var webURL: URL? {
        switch self {
        case .openURL(let url):
            return url
        case .webSearch(let query):
            var search = URLComponents(string: "https://www.google.com/search")
            search?.queryItems = [URLQueryItem(name: "q", value: query)]
            return search?.url
        default:
            return nil
        }
    }
}
