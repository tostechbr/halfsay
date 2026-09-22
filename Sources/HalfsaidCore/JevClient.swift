import Foundation

public struct JevAnswer: Decodable, Sendable {
    public var choice: String?
    public var probabilities: [String: Double]?
    public var confidence: Double?
    public var noul: Double?

    public init(choice: String? = nil, probabilities: [String: Double]? = nil, confidence: Double? = nil, noul: Double? = nil) {
        self.choice = choice
        self.probabilities = probabilities
        self.confidence = confidence
        self.noul = noul
    }
}

struct JevUsage: Decodable, Sendable {
    let inputTokens: Int
    enum CodingKeys: String, CodingKey { case inputTokens = "input_tokens" }
}

struct JevResponse: Decodable, Sendable {
    let answers: [String: JevAnswer]
    let usage: JevUsage?
}

public enum JevError: Error, Equatable, CustomStringConvertible {
    case http(status: Int, body: String)
    case missingAnswer(String)
    case unexpectedAnswer(String, String)

    public var description: String {
        switch self {
        case .http(let status, let body): "Jev HTTP \(status): \(body)"
        case .missingAnswer(let question): "Jev returned no answer for “\(question)”"
        case .unexpectedAnswer(let question, let value): "Jev answered “\(value)” to “\(question)”, not one of the options"
        }
    }
}

/// POST /v1/systemone. Docs: https://docs.typesafe.ai/api
public struct JevClient: Sendable {
    public static let endpoint = URL(string: "https://api.typesafe.ai/v1/systemone")!
    /// Sorted keys: same options in the same order on every run, so probe results are reproducible.
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    private let apiKey: String
    private let model: String
    private let session: URLSession

    public init(apiKey: String, model: String = "jev-latest", session: URLSession = .shared) {
        self.apiKey = apiKey
        self.model = model
        self.session = session
    }

    /// One fan-out request for one tail. Returns the decision and the input tokens billed.
    public func decide(tail: String, frontmost: String, apps: [String], spans: [String]) async throws -> (Decision, Int) {
        var request = URLRequest(url: Self.endpoint, timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try Self.encoder.encode(Questions.body(tail: tail, frontmost: frontmost, apps: apps, spans: spans, model: model))

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw JevError.http(status: status, body: String(decoding: data.prefix(300), as: UTF8.self)) }
        let decoded = try JSONDecoder().decode(JevResponse.self, from: data)
        return (try Decision(answers: decoded.answers), decoded.usage?.inputTokens ?? 0)
    }
}
