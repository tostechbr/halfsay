import Foundation

/// Words that frame a command rather than carry its argument, in English and Portuguese (normalized).
enum Vocabulary {
    static let filler: Set<String> = [
        "a", "an", "the", "and", "or", "to", "for", "of", "on", "in", "at", "my", "me", "please", "can", "you", "up", "now", "just", "then",
        "o", "os", "as", "um", "uma", "e", "ou", "de", "do", "da", "dos", "das", "no", "na", "nos", "nas", "em", "pra", "para", "por",
        "favor", "meu", "minha", "meus", "minhas", "mim", "ai", "entao", "depois", "agora",
    ]
    static let commandVerbs: Set<String> = [
        "search", "look", "find", "type", "write", "open", "go", "enter",
        "pesquisa", "pesquisar", "pesquise", "procura", "procurar", "busca", "buscar",
        "digita", "digitar", "digite", "escreve", "escrever", "escreva", "abre", "abrir", "abra", "vai", "ir", "entra", "entrar",
    ]
    /// An argument never starts with these ("digita | ls", "e | bom dia")...
    static let connectives: Set<String> = ["e", "and", "then", "depois", "ou", "or", "entao"]
    /// ...nor ends on a dangling one ("receita de |"). Not "com": "x dot com".
    static let prepositions: Set<String> = ["de", "do", "da", "dos", "das", "of", "to", "para", "pra", "em", "no", "na", "nos", "nas", "for", "in", "on", "at"]
    static let siteWords: Set<String> = ["site", "website", "page", "pagina", "link"]
    /// Said right after an app's name ("the notes app"): part of the mention.
    static let appWords: Set<String> = ["app", "application", "aplicativo", "programa"]

    /// Lowercased, without accents or edge punctuation: "Página," → "pagina".
    static func normalized(_ word: some StringProtocol) -> String {
        String(word).trimmingCharacters(in: .punctuationCharacters)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
