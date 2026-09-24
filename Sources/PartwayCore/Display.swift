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
        case .pressEnter: "press enter"
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
