/// The one request asked on every partial: all questions at once (speculative fan-out),
/// code reads only the answers the chosen action needs.
struct JevBody: Encodable, Sendable {
    struct State: Encodable, Sendable {
        let transcript: String
        let frontmostApp: String
        enum CodingKeys: String, CodingKey { case transcript, frontmostApp = "frontmost_app" }
    }

    struct Question: Encodable, Sendable {
        let type: String
        let instructions: String
        let criteria: [String: Criterion]
    }

    let model: String
    let state: State
    let questions: [String: Question]
}

enum Criterion: Encodable, Sendable {
    case text(String)
    /// The option key is the whole meaning (an app name, a span of speech): encodes as null.
    case candidate
    case detail(what: String, examples: [String])

    private struct Detail: Encodable { let what: String; let examples: [String] }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text): try container.encode(text)
        case .candidate: try container.encodeNil()
        case .detail(let what, let examples): try container.encode(Detail(what: what, examples: examples))
        }
    }
}

enum Questions {
    static let noApp = "none"
    static let noMatch = "no_match"
    static let maxOptions = 254  // Jev's Choice cap is 255; one slot stays for the escape hatch

    static let actions: [String: Criterion] = [
        Action.openApp.rawValue: .detail(what: "Launch or switch to an application",
                                         examples: ["open slack", "switch to the calendar", "abre o spotify"]),
        Action.newItem.rawValue: .detail(what: "Create a new note, document, tab or window in the frontmost app",
                                         examples: ["new tab", "start a new document", "cria uma nota nova"]),
        Action.openURL.rawValue: .detail(what: "Go to a specific website or web address",
                                         examples: ["go to github dot com", "open wikipedia.org", "entra no youtube"]),
        Action.webSearch.rawValue: .detail(what: "Search the web for something",
                                           examples: ["google the weather in lisbon", "look up how tall everest is", "procura o horário do jogo"]),
        Action.typeText.rawValue: .detail(what: "Type or write specific words into the frontmost app",
                                          examples: ["type see you tomorrow", "write buy milk", "put meeting notes as the heading", "escreve bom dia", "digita obrigado pela ajuda"]),
        Action.pressEnter.rawValue: .detail(what: "Press the Enter (Return) key, only when the speaker says enter or return out loud",
                                            examples: ["press enter", "hit return", "aperta enter", "dá enter"]),
        Action.none.rawValue: .detail(what: "Not a command for the computer yet: filler, thanks, or talk about something",
                                      examples: ["can you", "okay so", "thanks"]),
    ]

    static func body(tail: String, frontmost: String, apps: [String], spans: [String], model: String) -> JevBody {
        var questions: [String: JevBody.Question] = [
            "action": .init(type: "choice", instructions: "`transcript` is a live, possibly unfinished voice command to a Mac whose frontmost app is `frontmost_app`. What should the computer do?", criteria: actions),
            "complete": .init(type: "noul", instructions: "`transcript` is being spoken live. Is the command already fully stated, so that more words would not change what to do or its argument?", criteria: [
                "true": .text("Action and its argument are fully stated"),
                "false": .text("The speaker is likely mid-command"),
            ]),
        ]
        if !apps.isEmpty {
            questions["app"] = .init(type: "choice", instructions: "Which installed application does `transcript` name as the one to open or use?",
                                     criteria: options(apps, escape: (noApp, "No application is named")))
            questions["opens_app"] = .init(type: "noul", instructions: "Does `transcript` ask the computer to open or switch to an application, possibly along with other commands?", criteria: [
                "true": .text("It asks to open or switch to an app"),
                "false": .text("It does not ask to open an app"),
            ])
        }
        if !spans.isEmpty {
            questions["argument"] = .init(type: "choice", instructions: "Which span of `transcript` is exactly the command's argument: the search query, the website, or the text to type?",
                                          criteria: options(spans, escape: (noMatch, "The command has no search query, website or text yet")))
        }
        return JevBody(model: model, state: .init(transcript: tail, frontmostApp: frontmost), questions: questions)
    }

    private static func options(_ keys: [String], escape: (key: String, text: String)) -> [String: Criterion] {
        var criteria = Dictionary(keys.prefix(maxOptions).map { ($0, Criterion.candidate) }, uniquingKeysWith: { first, _ in first })
        criteria[escape.key] = .text(escape.text)
        return criteria
    }
}
