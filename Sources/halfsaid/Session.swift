import AppKit
import HalfsaidCore

/// Speech partials → Engine → Jev → executor, and how early each command fired.
@MainActor
final class Session {
    // Calibration knobs: a longer pause tolerates hesitation, a shorter one fires open actions sooner.
    static let pauseAfter: Duration = .milliseconds(600)
    static let utteranceEndsAfter: Duration = .seconds(2)

    var onUtteranceEnd: () -> Void = {}
    /// The floating bar, in the app; nil in the terminal-only `--text` mode.
    var bar: BarModel?

    private var client: JevClient
    private let appNames: [String]
    private let executor: Executor
    private let log: EventLog?
    private var engine = Engine()
    private var utterance = 1
    private var transcript = ""
    private var lastWordAt = ContinuousClock.now
    private var fired: [(command: Command, at: ContinuousClock.Instant)] = []
    private var frontmostHint: String?
    private var commands: Task<Void, Never>?
    private var silence: Task<Void, Never>?

    init(client: JevClient, apps: [String: URL], executor: Executor, log: EventLog?) {
        self.client = client
        self.appNames = apps.keys.sorted()
        self.executor = executor
        self.log = log
        engine.appAliases = InstalledApps.aliases(for: apps)
        engine.browsers = InstalledApps.names(of: NSWorkspace.shared.urlsForApplications(toOpen: URL(string: "https://example.com")!), among: apps)
    }

    /// A key pasted in the app replaces the one it started with.
    func use(apiKey: String) {
        client = JevClient(apiKey: apiKey)
    }

    /// A partial transcript: the whole utterance so far.
    func heard(_ text: String) {
        guard text != transcript else { return }  // only new words count as speech
        transcript = text
        lastWordAt = .now
        log?.write("heard", ["utterance": utterance, "text": text])
        waitForSilence()
        if let request = engine.hear(text) { ask(request) }
        bar?.heard(Transcript.words(text, consumed: engine.consumed))
    }

    /// The recognizer stopped by itself (long silence, error). The silence timer ends the utterance if it is running.
    func recognizerEnded() {
        if silence == nil { endUtterance() }
    }

    /// Listening stopped by hand: fire what the pause would, then close the utterance.
    func stop() {
        silence?.cancel()
        silence = nil
        handle(engine.pause())
        endUtterance()
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
        let utterance = self.utterance
        log?.write("ask", ["utterance": utterance, "seq": request.seq, "tail": request.text, "frontmost": frontmost])
        // ponytail: one request per partial, no debounce (~4/s while talking); debounce if cost matters
        Task {
            let start = ContinuousClock.now
            do {
                let (decision, tokens) = try await client.decide(tail: request.text, frontmost: frontmost, apps: appNames, spans: spans)
                log?.write("answer", [
                    "utterance": utterance, "seq": request.seq, "ms": Int((ContinuousClock.now - start).seconds * 1000),
                    "tokens": tokens, "action": decision.action.rawValue, "confidence": decision.confidence,
                    "app": decision.app, "app_p": decision.appProbability, "argument": decision.argument, "complete": decision.complete,
                    "opens_app": decision.opensApp,
                    "p": decision.actionProbabilities.reduce(into: [String: Double]()) { $0[$1.key.rawValue] = $1.value },
                ])
                show(request, decision)
                bar?.answered(decision)
                handle(engine.receive(decision, for: request))
            } catch {
                log?.write("error", ["utterance": utterance, "seq": request.seq, "message": "\(error)"])
                out("\n⚠︎ Jev: \(error)\n")
            }
        }
    }

    private func handle(_ step: Engine.Step) {
        if let command = step.command {
            fired.append((command, .now))
            log?.write("fire", ["utterance": utterance, "command": command.description])
            out("\n⚡ \(command)\n")
            bar?.fire(command, words: Transcript.words(transcript, consumed: engine.consumed))
            if case .openApp(let app) = command { frontmostHint = app }
            let previous = commands
            let utterance = self.utterance
            commands = Task {
                await previous?.value  // one at a time: ⌘N must not beat Notes to the front
                let failure = await executor.run(command)
                log?.write("run", ["utterance": utterance, "command": command.description, "ok": failure == nil, "error": failure])
                if let failure { bar?.notice = failure }
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
            log?.write("pause", ["utterance": utterance])
            bar?.paused = true
            handle(engine.pause())
            try? await Task.sleep(for: Self.utteranceEndsAfter - Self.pauseAfter)
            guard !Task.isCancelled else { return }
            endUtterance()
        }
    }

    private func endUtterance() {
        silence = nil
        defer {
            engine.reset()
            onUtteranceEnd()
        }
        guard !transcript.isEmpty || !fired.isEmpty else { return }  // the recognizer timing out on silence
        let leads = fired.map { (command: $0.command, seconds: (lastWordAt - $0.at).seconds) }  // > 0: before the last word
        log?.write("end", ["utterance": utterance, "transcript": transcript,
                           "fires": leads.map { ["command": $0.command.description, "lead_s": ($0.seconds * 100).rounded() / 100] as [String: Any] }])
        if !leads.isEmpty { out("\n") }  // leave the live line
        for (command, seconds) in leads { out("✓ \(command) · \(describeLead(seconds))\n") }
        bar?.finish(leads: leads.map { describeLead($0.seconds) })
        fired = []
        transcript = ""
        utterance += 1
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
