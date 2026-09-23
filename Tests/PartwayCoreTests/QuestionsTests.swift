import Foundation
import Testing
@testable import PartwayCore

private func json(_ body: JevBody) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: JevClient.encoder.encode(body)) as? [String: Any])
}

@Suite struct QuestionsTests {
    @Test func bodyCarriesStateAndFiveQuestions() throws {
        let body = try json(Questions.body(tail: "open notes", frontmost: "Finder", apps: ["Notes"], spans: ["notes"], model: "jev-latest"))
        #expect(body["model"] as? String == "jev-latest")
        let state = try #require(body["state"] as? [String: Any])
        #expect(state["transcript"] as? String == "open notes")
        #expect(state["frontmost_app"] as? String == "Finder")
        let questions = try #require(body["questions"] as? [String: [String: Any]])
        #expect(Set(questions.keys) == ["action", "app", "argument", "complete", "opens_app"])
        #expect(questions["complete"]?["type"] as? String == "noul")
        #expect(questions["opens_app"]?["type"] as? String == "noul")
        let actions = try #require(questions["action"]?["criteria"] as? [String: [String: Any]])
        #expect(Set(actions.keys) == Set(Action.allCases.map(\.rawValue)))
        #expect(actions["type_text"]?["what"] is String)
        #expect(actions["type_text"]?["examples"] is [String])
    }

    @Test func candidatesAreBareKeysPlusAnEscapeHatch() throws {
        let body = try json(Questions.body(tail: "open notes", frontmost: "Finder", apps: ["Notes"], spans: ["notes"], model: "m"))
        let questions = try #require(body["questions"] as? [String: [String: Any]])
        let apps = try #require(questions["app"]?["criteria"] as? [String: Any])
        #expect(apps["Notes"] is NSNull)
        #expect(apps["none"] is String)
        let spans = try #require(questions["argument"]?["criteria"] as? [String: Any])
        #expect(spans["notes"] is NSNull)
        #expect(spans[Questions.noMatch] is String)
    }

    @Test func optionListsStayUnderTheChoiceCap() throws {
        let apps = (1...300).map { "App\($0)" }
        let body = try json(Questions.body(tail: "t", frontmost: "Finder", apps: apps, spans: apps, model: "m"))
        let questions = try #require(body["questions"] as? [String: [String: Any]])
        #expect((questions["app"]?["criteria"] as? [String: Any])?.count == 255)
        #expect((questions["argument"]?["criteria"] as? [String: Any])?.count == 255)
    }

    @Test func emptyListsDropTheirQuestion() throws {
        let body = try json(Questions.body(tail: "t", frontmost: "Finder", apps: [], spans: [], model: "m"))
        let questions = try #require(body["questions"] as? [String: Any])
        #expect(Set(questions.keys) == ["action", "complete"])
    }
}
