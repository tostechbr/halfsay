import Foundation
import Testing
@testable import HalfsaidCore

let fixture = Data("""
{"model":"jev-1.13.0","answers":{
  "action":{"type":"choice","choice":"open_app","probabilities":{"open_app":0.97,"none":0.03},"confidence":0.9},
  "app":{"type":"choice","choice":"Notes","probabilities":{"Notes":0.96,"none":0.04},"confidence":0.9},
  "argument":{"type":"choice","choice":"no_match","probabilities":{"no_match":1.0},"confidence":1.0},
  "complete":{"type":"noul","noul":0.81}},
 "usage":{"input_tokens":1581,"output_tokens":20}}
""".utf8)

private func json(_ body: JevBody) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: JevClient.encoder.encode(body)) as? [String: Any])
}

@Suite struct QuestionsTests {
    @Test func bodyCarriesStateAndFourQuestions() throws {
        let body = try json(Questions.body(tail: "open notes", frontmost: "Finder", apps: ["Notes"], spans: ["notes"], model: "jev-latest"))
        #expect(body["model"] as? String == "jev-latest")
        let state = try #require(body["state"] as? [String: Any])
        #expect(state["transcript"] as? String == "open notes")
        #expect(state["frontmost_app"] as? String == "Finder")
        let questions = try #require(body["questions"] as? [String: [String: Any]])
        #expect(Set(questions.keys) == ["action", "app", "argument", "complete"])
        #expect(questions["complete"]?["type"] as? String == "noul")
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

@Suite struct DecisionTests {
    @Test func mapsTypedAnswers() throws {
        let response = try JSONDecoder().decode(JevResponse.self, from: fixture)
        let decision = try Decision(answers: response.answers)
        #expect(decision == Decision(action: .openApp, confidence: 0.9, actionProbabilities: [.openApp: 0.97, .none: 0.03],
                                     app: "Notes", appProbability: 0.96, argument: nil, complete: 0.81))
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

final class StubProtocol: URLProtocol {
    nonisolated(unsafe) static var reply: (status: Int, body: Data) = (200, Data())
    nonisolated(unsafe) static var seen: URLRequest?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func stopLoading() {}
    override func startLoading() {
        Self.seen = request
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.reply.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.reply.body)
        client?.urlProtocolDidFinishLoading(self)
    }
}

@Suite(.serialized) struct JevClientTests {
    let client: JevClient = {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubProtocol.self]
        return JevClient(apiKey: "test-key", session: URLSession(configuration: config))
    }()

    @Test func postsToSystemOneAndDecodes() async throws {
        StubProtocol.reply = (200, fixture)
        let (decision, tokens) = try await client.decide(tail: "open notes", frontmost: "Finder", apps: ["Notes"], spans: ["notes"])
        #expect(decision.action == .openApp)
        #expect(tokens == 1581)
        let request = try #require(StubProtocol.seen)
        #expect(request.url == JevClient.endpoint)
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-key")
    }

    @Test func httpErrorSurfacesStatusAndBody() async {
        StubProtocol.reply = (401, Data("bad key".utf8))
        await #expect(throws: JevError.http(status: 401, body: "bad key")) {
            _ = try await client.decide(tail: "t", frontmost: "Finder", apps: [], spans: [])
        }
    }
}
