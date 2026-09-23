import Foundation
import Testing
@testable import HalfsaidCore

@Suite struct DisplayTests {
    @Test func actionsHaveShortLabels() {
        #expect(Action.openApp.label == "open app")
        #expect(Action.typeText.label == "type text")
        #expect(Action.none.label == "not yet")
    }

    @Test func topActionsComeMostLikelyFirst() {
        let decision = Decision(action: .openApp, confidence: 0.79,
                                actionProbabilities: [.openApp: 0.82, .newItem: 0.15, .none: 0.02, .typeText: 0.01])
        #expect(decision.top(3) == [ActionScore(action: .openApp, probability: 0.82),
                                    ActionScore(action: .newItem, probability: 0.15),
                                    ActionScore(action: .none, probability: 0.02)])
    }

    @Test func tiesBreakTheSameWayEveryTime() {
        let decision = Decision(action: .none, confidence: 0, actionProbabilities: [.webSearch: 0.5, .openURL: 0.5])
        #expect(decision.top(2).map(\.action) == [.openURL, .webSearch])
    }

    @Test func leadReadsLikeTheBar() {
        #expect(describeLead(1.21) == "1.21 s before you finished")
        #expect(describeLead(-0.64) == "0.64 s after you stopped")
    }

    @Test func spokenWordsMarkWhatWasUsed() {
        let words = Transcript.words("abre as notas e digita", consumed: 4)
        #expect(words.map(\.used) == [true, true, true, true, false])
        #expect(Transcript.words("abre as notas e digita", consumed: 4, limit: 2) == [SpokenWord(text: "e", used: true), SpokenWord(text: "digita", used: false)])
    }
}

@Suite struct APIKeyTests {
    let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

    @Test func environmentWins() throws {
        try Data("from-file\n".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(APIKey.load(environment: ["TYPESAFE_API_KEY": "from-env"], file: file) == "from-env")
    }

    @Test func fileIsTheFallback() throws {
        try Data("  from-file\n".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(APIKey.load(environment: ["TYPESAFE_API_KEY": " "], file: file) == "from-file")
    }

    @Test func noKeyAnywhere() {
        #expect(APIKey.load(environment: [:], file: file) == nil)
    }
}
