import AppKit
import Foundation
import HalfsayCore

/// Replays sentences word by word as if they were live speech-recognition partials, through the same
/// Engine and questions the app uses, and prints where each command fires.
/// Sequential: each word waits for Jev's answer, so "after k words" ignores network lag.
@main struct Probe {
    static func main() async {
        guard let key = ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"], !key.isEmpty else {
            fail("Set TYPESAFE_API_KEY (get one at https://console.typesafe.ai).")
        }
        let args = CommandLine.arguments.dropFirst()
        let sentences = args.isEmpty ? demo : args.map { Sentence(frontmost: "Finder", text: $0) }
        let client = JevClient(apiKey: key)
        let urls = InstalledApps.urls()
        let apps = urls.keys.sorted()
        let aliases = InstalledApps.aliases(for: urls)
        let openers = await MainActor.run { NSWorkspace.shared.urlsForApplications(toOpen: URL(string: "https://example.com")!) }
        let browsers = InstalledApps.names(of: openers, among: urls)
        do {
            let replays = try await withThrowingTaskGroup(of: (Int, Replay).self) { group in
                for (index, sentence) in sentences.enumerated() {
                    group.addTask {
                        var replayer = Replayer(client: client, apps: apps, aliases: aliases, browsers: browsers, sentence: sentence)
                        return (index, try await replayer.run())
                    }
                }
                var done: [(Int, Replay)] = []
                for try await replay in group { done.append(replay) }
                return done.sorted { $0.0 < $1.0 }.map(\.1)
            }
            print(render(replays, apps: apps.count))
        } catch {
            fail("\(error)")
        }
    }
}

/// The eval: each sentence with the commands it should fire, in order. Failures found on 22/09 stay here as regressions.
let demo = [
    Sentence(frontmost: "Finder", text: "can you open up the notes app for me and once you're there can you create a new note", expect: ["open Notes", "new item"]),
    Sentence(frontmost: "Notes", text: "and inside this new note let's make the title say hello", expect: ["type “hello”"]),
    Sentence(frontmost: "Finder", text: "can you open up safari and google search norbert wiener", expect: ["open Safari", "search “norbert wiener”"]),
    Sentence(frontmost: "Safari", text: "now can you open up x dot com", expect: ["open https://x.com"]),
    Sentence(frontmost: "Finder", text: "abre o safari e pesquisa receita de pão de queijo", expect: ["open Safari", "search “receita de pão de queijo”"]),
    Sentence(frontmost: "Finder", text: "i was just telling my friend about the notes app", expect: []),
    Sentence(frontmost: "Terminal", text: "abre as notas e cria uma nota nova", expect: ["open Notes", "new item"]),
    Sentence(frontmost: "Finder", text: "pesquisa receita de bolo e depois abre as notas", expect: ["search “receita de bolo”", "open Notes"]),
    Sentence(frontmost: "Finder", text: "open safari and search for cheap flights to lisbon and then open notes",
             expect: ["open Safari", "search “cheap flights to lisbon”", "open Notes"]),
    Sentence(frontmost: "Finder", text: "abre o google e pesquisa pão de queijo", expect: ["search “pão de queijo”"]),
    Sentence(frontmost: "Notes", text: "digita nos vemos amanhã", expect: ["type “nos vemos amanhã”"]),
    Sentence(frontmost: "Finder", text: "abre as notas e digita comprar pão de queijo", expect: ["open Notes", "type “comprar pão de queijo”"]),
    Sentence(frontmost: "Finder", text: "abre o notes escreve lista de compras", expect: ["open Notes", "type “lista de compras”"]),
    Sentence(frontmost: "Finder", text: "entra no site do youtube", expect: ["open https://youtube.com"]),
    Sentence(frontmost: "Terminal", text: "abre o linkedin pelo google", expect: ["open https://linkedin.com"]),
]

struct Sentence: Sendable {
    let frontmost: String
    let text: String
    var expect: [String]? = nil
}

struct Row: Sendable {
    let heard: Int
    let tail: String
    let decision: Decision
    let ms: Double
    let tokens: Int
    let fired: Command?
}

struct Fire: Sendable {
    let heard: Int
    let command: Command
    let atPause: Bool
}

struct Replay: Sendable {
    let sentence: Sentence
    var rows: [Row] = []
    var fires: [Fire] = []

    var passed: Bool { sentence.expect == fires.map(\.command.description) }
}

struct Replayer {
    let client: JevClient
    let apps: [String]
    private var engine = Engine()
    private var frontmost: String
    private var replay: Replay

    init(client: JevClient, apps: [String], aliases: [String: [String]], browsers: Set<String>, sentence: Sentence) {
        self.client = client
        self.apps = apps
        engine.appAliases = aliases
        engine.browsers = browsers
        self.frontmost = sentence.frontmost
        self.replay = Replay(sentence: sentence)
    }

    mutating func run() async throws -> Replay {
        let words = replay.sentence.text.split(separator: " ")
        for heard in 1...words.count {
            try await follow(engine.hear(words.prefix(heard).joined(separator: " ")), heard: heard, paused: false)
        }
        let step = engine.pause()
        record(step.command, heard: words.count, paused: true)
        try await follow(step.request, heard: words.count, paused: true)
        return replay
    }

    private mutating func follow(_ first: Engine.Request?, heard: Int, paused: Bool) async throws {
        var next = first
        while let request = next {
            let start = Date()
            let (decision, tokens) = try await client.decide(tail: request.text, frontmost: frontmost, apps: apps,
                                                             spans: Candidates.spans(of: request.tail))
            let step = engine.receive(decision, for: request)
            replay.rows.append(Row(heard: heard, tail: request.text, decision: decision,
                                   ms: Date().timeIntervalSince(start) * 1000, tokens: tokens, fired: step.command))
            record(step.command, heard: heard, paused: paused)
            next = step.request
        }
    }

    private mutating func record(_ command: Command?, heard: Int, paused: Bool) {
        guard let command else { return }
        replay.fires.append(Fire(heard: heard, command: command, atPause: paused))
        if case .openApp(let app) = command { frontmost = app }
    }
}

func render(_ replays: [Replay], apps: Int) -> String {
    var lines: [String] = []
    for replay in replays {
        let total = replay.sentence.text.split(separator: " ").count
        lines += ["### “\(replay.sentence.text)” (frontmost: \(replay.sentence.frontmost))", "",
                  "| heard | tail sent to Jev | action | app | argument | complete | ms | fired |",
                  "|---:|---|---|---|---|---:|---:|---|"]
        for row in replay.rows {
            let d = row.decision
            let app = d.app.map { "\($0) \(f(d.appProbability))" } ?? "–"
            let argument = d.argument.map { "“\($0)”" } ?? "–"
            lines.append("| \(row.heard)/\(total) | \(row.tail) | \(d.action.rawValue) \(f(d.confidence)) | \(app) | \(argument) | \(f(d.complete)) | \(Int(row.ms)) | \(row.fired.map { "⚡ \($0)" } ?? "") |")
        }
        for fire in replay.fires where fire.atPause {
            lines.append("| ⏸ | (speaker stops) | | | | | | ⚡ \(fire.command) |")
        }
        let fired = replay.fires.map { fire in
            fire.atPause ? "\(fire.command) at the pause" : "\(fire.command) after \(fire.heard)/\(total) words (\(total - fire.heard) early)"
        }
        lines += ["", "**Fired:** " + (fired.isEmpty ? "nothing" : fired.joined(separator: " · "))]
        if let expect = replay.sentence.expect {
            lines.append(replay.passed ? "✅ as expected" : "❌ expected: " + (expect.isEmpty ? "nothing" : expect.joined(separator: " · ")))
        }
        lines.append("")
    }
    let graded = replays.filter { $0.sentence.expect != nil }
    if !graded.isEmpty { lines.append("**Eval: \(graded.filter(\.passed).count)/\(graded.count) as expected**\n") }
    let rows = replays.flatMap(\.rows)
    guard !rows.isEmpty else { return lines.joined(separator: "\n") }
    let ms = rows.map(\.ms).sorted()
    let tokens = rows.map(\.tokens).sorted()
    lines.append("\(rows.count) Jev calls · \(apps) apps offered · latency median \(Int(ms[ms.count / 2])) ms, p90 \(Int(ms[ms.count * 9 / 10])) ms · median \(tokens[tokens.count / 2]) input tokens per call")
    return lines.joined(separator: "\n")
}

func f(_ x: Double) -> String { String(format: "%.2f", x) }

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}
