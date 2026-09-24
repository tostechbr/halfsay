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
        // Jev must never search for, or type, the command itself: no span of only framing words ("e pesquisar"),
        // none starting with the command ("digita ls"), none ending mid-phrase ("receita de").
        let framing = Vocabulary.filler.union(Vocabulary.commandVerbs)
        let leading = Vocabulary.commandVerbs.union(Vocabulary.connectives)
        let trailing = Vocabulary.connectives.union(Vocabulary.prepositions)
        var seen = Set<String>()
        var spans: [String] = []
        for start in tail.indices {
            for end in start..<min(start + maxSpanWords, tail.count) {
                let words = tail[start...end]
                let normalized = words.map(Vocabulary.normalized)
                guard !normalized.allSatisfy(framing.contains), !leading.contains(normalized[0]),
                      !trailing.contains(normalized[normalized.count - 1]) else { continue }
                // Nor does it run into the next command: "digita claude | e dá enter" types "claude".
                let chained = normalized.indices.dropFirst().contains { index in
                    Vocabulary.connectives.contains(normalized[index])
                        && normalized[(index + 1)...].contains { Vocabulary.commandVerbs.contains($0) || Vocabulary.keys.contains($0) }
                }
                guard !chained else { continue }
                let span = words.joined(separator: " ")
                if seen.insert(span).inserted { spans.append(span) }
            }
        }
        return spans
    }
}
