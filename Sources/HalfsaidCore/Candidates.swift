/// Code proposes, Jev picks: every short contiguous span of the tail may be the argument,
/// and the chosen one is copied verbatim. Jev never writes text.
public enum Candidates {
    static let maxSpanWords = 8
    static let window = 30

    public static func spans(of words: [String]) -> [String] {
        // ponytail: last 30 words only (≤212 spans, under Jev's 255-option cap); a long monologue loses its start
        let tail = words.suffix(window)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty }
        var seen = Set<String>()
        var spans: [String] = []
        for start in tail.indices {
            for end in start..<min(start + maxSpanWords, tail.count) {
                let span = tail[start...end].joined(separator: " ")
                if seen.insert(span).inserted { spans.append(span) }
            }
        }
        return spans
    }
}
