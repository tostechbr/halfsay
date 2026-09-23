import Foundation
import Testing
@testable import PartwayCore

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

    @Test func savedKeyLoadsBackAndStaysPrivate() throws {
        let nested = file.appendingPathComponent("partway/api-key")
        defer { try? FileManager.default.removeItem(at: file) }
        try APIKey.save("  pasted-key \n", to: nested)
        #expect(APIKey.load(environment: [:], file: nested) == "pasted-key")
        let permissions = try FileManager.default.attributesOfItem(atPath: nested.path)[.posixPermissions] as? Int
        #expect(permissions == 0o600)
    }

    @Test func blankKeyIsNotSaved() {
        #expect(throws: APIKey.Blank.self) { try APIKey.save("   ", to: file) }
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }
}
