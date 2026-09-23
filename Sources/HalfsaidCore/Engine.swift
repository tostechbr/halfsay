/// Turns a live transcript plus Jev decisions into commands.
///
/// Every partial transcript becomes a request for the words not yet used ("tail").
/// Closed actions fire once `stableCount` partials in a row agree; open actions fire when the speaker pauses.
/// Firing consumes the tail, so the rest of the sentence becomes the next command.
public struct Engine: Sendable {
    public struct Request: Equatable, Sendable {
        public let seq: Int
        public let epoch: Int
        /// Words already consumed when this tail was cut.
        public let consumed: Int
        public let tail: [String]
        public var text: String { tail.joined(separator: " ") }
    }

    public struct Step: Equatable, Sendable {
        public var command: Command?
        /// Leftover words to ask about right away (the speaker may already be silent).
        public var request: Request?
    }

    public var earlyThreshold: Double
    /// Opening an app is cheap to undo: a lower bar mid-sentence, but only for an app named beyond doubt (`sureApp`).
    public var openAppThreshold: Double
    public var sureApp: Double
    public var pauseThreshold: Double
    public var stableCount: Int
    public private(set) var consumed = 0
    public var appAliases: [String: [String]] = [:]

    private var words: [String] = []
    private var epoch = 0
    private var seq = 0
    private var lastTail: [String] = []
    private var latest: (request: Request, decision: Decision)?
    private var paused = false
    private var streak: (command: Command, count: Int)?

    public init(earlyThreshold: Double = 0.85, openAppThreshold: Double = 0.8, sureApp: Double = 0.95,
                pauseThreshold: Double = 0.7, stableCount: Int = 2) {
        self.earlyThreshold = earlyThreshold
        self.openAppThreshold = openAppThreshold
        self.sureApp = sureApp
        self.pauseThreshold = pauseThreshold
        self.stableCount = stableCount
    }

    /// A new partial from speech recognition: the whole utterance so far.
    public mutating func hear(_ transcript: String) -> Request? {
        // ponytail: word-count offsets; a recognizer rewrite that merges words ("x dot com" → "x.com") shifts them
        words = transcript.split(whereSeparator: \.isWhitespace).map(String.init)
        paused = false
        return nextRequest()
    }

    /// The speaker went quiet.
    public mutating func pause() -> Step {
        paused = true
        guard let latest, latest.request.seq == seq else { return Step() }  // newest answer still in flight
        return fire(onPause(latest.decision), argument: latest.decision.argument, consuming: latest.request)
    }

    /// Jev answered `request`.
    public mutating func receive(_ decision: Decision, for request: Request) -> Step {
        guard request.epoch == epoch, request.seq > (latest?.request.seq ?? 0) else { return Step() }  // stale or late
        latest = (request, decision)
        let command = paused && request.seq == seq ? onPause(decision) : onPartial(decision)
        return fire(command, argument: decision.argument, consuming: request)
    }

    /// Speech recognition restarted: a fresh utterance.
    public mutating func reset() {
        words = []
        consumed = 0
        epoch += 1
        lastTail = []
        latest = nil
        paused = false
        streak = nil
    }

    private mutating func nextRequest() -> Request? {
        let tail = Array(words.dropFirst(consumed))
        guard !tail.isEmpty, tail != lastTail else { return nil }
        lastTail = tail
        seq += 1
        return Request(seq: seq, epoch: epoch, consumed: consumed, tail: tail)
    }

    private mutating func onPartial(_ d: Decision) -> Command? {
        // Either signal may carry "open the app": the action choice, or the yes/no that survives a second command.
        let asksForApp = max(d.opensApp, d.action == .openApp ? d.confidence : 0)
        let candidate: Command? = if asksForApp >= openAppThreshold && d.appProbability >= sureApp {
            d.app.map(Command.openApp)
        } else if d.action == .newItem && d.confidence >= earlyThreshold {
            .newItem
        } else {
            nil
        }
        guard let candidate else {
            streak = nil
            return nil
        }
        let count = (streak.flatMap { $0.command == candidate ? $0.count : nil } ?? 0) + 1
        streak = (candidate, count)
        return count >= stableCount ? candidate : nil
    }

    /// Actions grouped by what ends up on screen: going to a site and searching for it both put it there.
    static let outcomes: [[Action]] = [[.openURL, .webSearch], [.openApp], [.newItem], [.typeText]]

    /// Acts on the chance of an outcome, not on how concentrated one label is: "abre o LinkedIn no Google" splits
    /// 0.72 site / 0.15 browser / 0.13 search, so the label's confidence is 0.66 though site or search both get there.
    private func onPause(_ d: Decision) -> Command? {
        let scored = Self.outcomes.map { outcome in (outcome: outcome, chance: outcome.reduce(0) { $0 + d.probability(of: $1) }) }
        guard let best = scored.max(by: { $0.chance < $1.chance }), best.chance >= pauseThreshold else { return nil }
        for action in best.outcome.sorted(by: { d.probability(of: $0) > d.probability(of: $1) }) {
            if let command = command(for: action, d) { return command }  // a "site" that is no address falls back to search
        }
        return nil
    }

    private func command(for action: Action, _ d: Decision) -> Command? {
        switch action {
        case .openApp: d.appProbability >= pauseThreshold ? d.app.map(Command.openApp) : nil
        case .newItem: .newItem
        case .openURL: d.argument.flatMap(Site.url).map(Command.openURL)
        case .webSearch: d.argument.map(Command.webSearch)
        case .typeText: d.argument.map(Command.typeText)
        case .none: nil
        }
    }

    private mutating func fire(_ command: Command?, argument: String?, consuming request: Request) -> Step {
        guard let command else { return Step() }
        consumed = request.consumed + Self.wordsUsed(by: command, argument: argument, aliases: aliases(of: command), in: request.tail)
        epoch += 1
        latest = nil
        streak = nil
        lastTail = []
        return Step(command: command, request: nextRequest())
    }

    private func aliases(of command: Command) -> [String] {
        guard case .openApp(let app) = command else { return [] }
        return [app] + (appAliases[app] ?? [])
    }

    /// A command ends where its own words end, so the one chained after it survives even when both were said
    /// before anything fired: open ends at the app's name ("abre as notas | e digita oi"), search, site and typing at
    /// their argument ("search cake recipes | and open notes").
    static func wordsUsed(by command: Command, argument: String?, aliases: [String], in tail: [String]) -> Int {
        let words = tail.map(Vocabulary.normalized)
        switch command {
        case .openApp:
            return mention(of: aliases, in: words) ?? tail.count
        case .newItem:
            return tail.count  // ponytail: no span for "a new note", so a command said in the same breath after it is lost
        case .openURL, .webSearch, .typeText:
            let span = argument.map { $0.split(separator: " ").map(Vocabulary.normalized) } ?? []
            return end(of: span, in: words) ?? tail.count
        }
    }

    /// Where the earliest full name ends, else the earliest first word ("google" for Google Chrome), plus a trailing "app".
    private static func mention(of aliases: [String], in words: [String]) -> Int? {
        let names = aliases.map { $0.split(separator: " ").map(Vocabulary.normalized) }
        guard var end = names.compactMap({ end(of: $0, in: words) }).min()
            ?? names.compactMap({ $0.first.flatMap { end(of: [$0], in: words) } }).min() else { return nil }
        while end < words.count, Vocabulary.appWords.contains(words[end]) { end += 1 }
        return end
    }

    private static func end(of span: [String], in words: [String]) -> Int? {
        guard !span.isEmpty, span.count <= words.count else { return nil }
        for start in 0...(words.count - span.count) where Array(words[start..<start + span.count]) == span {
            return start + span.count
        }
        return nil
    }
}
