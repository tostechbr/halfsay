import Foundation
import Testing
@testable import HalfsayCore

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
