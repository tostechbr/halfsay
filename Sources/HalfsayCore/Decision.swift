/// Jev's typed answers for one transcript tail.
public struct Decision: Equatable, Sendable {
    public var action: Action
    public var confidence: Double
    public var actionProbabilities: [Action: Double]
    public var app: String?
    public var appProbability: Double
    public var argument: String?
    /// "Is the command fully stated?" Shown, never used to fire: it swings on dangling words ("for", "and").
    public var complete: Double
    /// Yes/no "does it ask to open an app?". Unlike the single action choice, it stays high when a second
    /// command follows ("abre as notas e digita…"), where the choice splits between two valid actions.
    public var opensApp: Double

    public init(action: Action, confidence: Double, actionProbabilities: [Action: Double] = [:],
                app: String? = nil, appProbability: Double = 0, argument: String? = nil, complete: Double = 0,
                opensApp: Double = 0) {
        self.action = action
        self.confidence = confidence
        self.actionProbabilities = actionProbabilities
        self.app = app
        self.appProbability = appProbability
        self.argument = argument
        self.complete = complete
        self.opensApp = opensApp
    }

    /// Jev's probability for `action`; a decision built by hand carries only the chosen action's confidence.
    func probability(of action: Action) -> Double {
        actionProbabilities[action] ?? (action == self.action ? confidence : 0)
    }

    init(answers: [String: JevAnswer]) throws {
        guard let answer = answers["action"], let choice = answer.choice else { throw JevError.missingAnswer("action") }
        guard let action = Action(rawValue: choice) else { throw JevError.unexpectedAnswer("action", choice) }
        let app = answers["app"]?.choice.flatMap { $0 == Questions.noApp ? nil : $0 }
        self.init(
            action: action,
            confidence: answer.confidence ?? 0,
            actionProbabilities: Dictionary(uniqueKeysWithValues: (answer.probabilities ?? [:]).compactMap { key, p in
                Action(rawValue: key).map { ($0, p) }
            }),
            app: app,
            appProbability: app.flatMap { answers["app"]?.probabilities?[$0] } ?? 0,
            argument: answers["argument"]?.choice.flatMap { $0 == Questions.noMatch ? nil : $0 },
            complete: answers["complete"]?.noul ?? 0,
            opensApp: answers["opens_app"]?.noul ?? 0
        )
    }
}
