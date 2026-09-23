import AppKit
import HalfsaidCore

/// Speech partials → Engine → Jev → executor, and how early each command fired.
@MainActor
final class Session {
    // Calibration knobs: a longer pause tolerates hesitation, a shorter one fires open actions sooner.
    static let pauseAfter: Duration = .milliseconds(600)
    static let utteranceEndsAfter: Duration = .seconds(2)

    var onUtteranceEnd: () -> Void = {}

    private let client: JevClient
    private let appNames: [String]
    private let executor: Executor
    private var engine = Engine()
    private var transcript = ""
    private var lastWordAt = ContinuousClock.now
    private var fired: [(command: Command, at: ContinuousClock.Instant)] = []
    private var frontmostHint: String?
    private var commands: Task<Void, Never>?
    private var silence: Task<Void, Never>?

    init(client: JevClient, apps: [String: URL], executor: Executor) {
        self.client = client
        self.appNames = apps.keys.sorted()
        self.executor = executor
    }

    /// A partial transcript: the whole utterance so far.
    func heard(_ text: String) {
        guard text != transcript else { return }  // only new words count as speech
        transcript = text
        lastWordAt = .now
        waitForSilence()
        if let request = engine.hear(text) { ask(request) }
    }

    /// The recognizer stopped by itself (long silence, error). The silence timer ends the utterance if it is running.
    func recognizerEnded() {
        if silence == nil { endUtterance() }
    }

    /// Feeds a sentence word by word at speaking pace, like the mic would, then waits for the commands to finish.
    func replay(_ sentence: String, wpm: Double) async {
        let words = sentence.split(separator: " ")
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            onUtteranceEnd = { [weak self] in
                self?.onUtteranceEnd = {}
                done.resume()
            }
            Task {
                for count in 1...words.count {
                    heard(words.prefix(count).joined(separator: " "))
                    try? await Task.sleep(for: .seconds(60 / wpm))
                }
            }
        }
        await commands?.value
    }

    private func ask(_ request: Engine.Request) {
        let frontmost = frontmostHint ?? NSWorkspace.shared.frontmostApplication?.localizedName ?? "Finder"
        let spans = Candidates.spans(of: request.tail)
        // ponytail: one request per partial, no debounce (~4/s while talking); debounce if cost matters
        Task {
            do {
                let (decision, _) = try await client.decide(tail: request.text, frontmost: frontmost, apps: appNames, spans: spans)
                show(request, decision)
                handle(engine.receive(decision, for: request))
            } catch {
                out("\n⚠︎ Jev: \(error)\n")
            }
        }
    }

    private func handle(_ step: Engine.Step) {
        if let command = step.command {
            fired.append((command, .now))
            out("\n⚡ \(command)\n")
            if case .openApp(let app) = command { frontmostHint = app }
            let previous = commands
            commands = Task {
                await previous?.value  // one at a time: ⌘N must not beat Notes to the front
                await executor.run(command)
                if case .openApp(let app) = command, frontmostHint == app { frontmostHint = nil }
            }
        }
        if let request = step.request { ask(request) }
    }

    private func waitForSilence() {
        silence?.cancel()
        silence = Task {
            try? await Task.sleep(for: Self.pauseAfter)
            guard !Task.isCancelled else { return }
            handle(engine.pause())
            try? await Task.sleep(for: Self.utteranceEndsAfter - Self.pauseAfter)
            guard !Task.isCancelled else { return }
            endUtterance()
        }
    }

    private func endUtterance() {
        silence = nil
        if !fired.isEmpty { out("\n") }  // leave the live line
        for (command, at) in fired {
            let lead = (lastWordAt - at).seconds
            out(lead > 0 ? "✓ \(command) · \(format(lead)) s before you finished\n" : "✓ \(command) · \(format(-lead)) s after you stopped\n")
        }
        fired = []
        engine.reset()
        transcript = ""
        onUtteranceEnd()
    }

    private func show(_ request: Engine.Request, _ d: Decision) {
        let app = d.action == .openApp ? " · \(d.app ?? "?")" : ""
        let argument = d.argument.map { " · “\($0)”" } ?? ""
        out("\u{1B}[2K\r🎙 …\(request.text.suffix(50))  → \(d.action.rawValue) \(format(d.confidence))\(app)\(argument)")
    }
}

private func format(_ x: Double) -> String { String(format: "%.2f", x) }

extension Duration {
    var seconds: Double { Double(components.seconds) + Double(components.attoseconds) / 1e18 }
}
