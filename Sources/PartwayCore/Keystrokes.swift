public enum Keystrokes {
    /// A keyboard event carries at most 20 UTF-16 units; split on character boundaries so nothing is cut in half.
    public static func chunks(_ text: String, limit: Int = 20) -> [String] {
        var chunks: [String] = []
        var current = ""
        for character in text {
            if !current.isEmpty, current.utf16.count + character.utf16.count > limit {
                chunks.append(current)
                current = ""
            }
            current.append(character)
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
}
