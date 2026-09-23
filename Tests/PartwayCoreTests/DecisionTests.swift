import Foundation
import Testing
@testable import PartwayCore

let fixture = Data("""
{"model":"jev-1.13.0","answers":{
  "action":{"type":"choice","choice":"open_app","probabilities":{"open_app":0.97,"none":0.03},"confidence":0.9},
  "app":{"type":"choice","choice":"Notes","probabilities":{"Notes":0.96,"none":0.04},"confidence":0.9},
  "argument":{"type":"choice","choice":"no_match","probabilities":{"no_match":1.0},"confidence":1.0},
  "complete":{"type":"noul","noul":0.81},
  "opens_app":{"type":"noul","noul":0.9}},
 "usage":{"input_tokens":1581,"output_tokens":20}}
""".utf8)

@Suite struct DecisionTests {
    @Test func mapsTypedAnswers() throws {
        let response = try JSONDecoder().decode(JevResponse.self, from: fixture)
        let decision = try Decision(answers: response.answers)
        #expect(decision == Decision(action: .openApp, confidence: 0.9, actionProbabilities: [.openApp: 0.97, .none: 0.03],
                                     app: "Notes", appProbability: 0.96, argument: nil, complete: 0.81, opensApp: 0.9))
        #expect(response.usage?.inputTokens == 1581)
    }

    @Test func noneAppMeansNoApp() throws {
        let answers = ["action": JevAnswer(choice: "web_search", confidence: 1),
                       "app": JevAnswer(choice: "none", probabilities: ["none": 1]),
                       "argument": JevAnswer(choice: "lisbon")]
        let decision = try Decision(answers: answers)
        #expect(decision.app == nil)
        #expect(decision.appProbability == 0)
        #expect(decision.argument == "lisbon")
    }

    @Test func missingOrUnknownActionThrows() {
        #expect(throws: JevError.missingAnswer("action")) { try Decision(answers: [:]) }
        #expect(throws: JevError.unexpectedAnswer("action", "fly")) { try Decision(answers: ["action": JevAnswer(choice: "fly")]) }
    }
}
