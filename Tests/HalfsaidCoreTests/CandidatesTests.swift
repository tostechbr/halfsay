import Foundation
import Testing
@testable import HalfsaidCore

@Suite struct CandidatesTests {
    @Test func everyContiguousSpanIsACandidate() {
        let spans = Candidates.spans(of: ["google", "search", "norbert", "wiener"])
        #expect(spans.count == 10)
        #expect(spans.contains("norbert wiener"))
        #expect(spans.contains("google search norbert wiener"))
    }

    @Test func duplicatesAppearOnce() {
        #expect(Candidates.spans(of: ["no", "no", "no"]) == ["no", "no no", "no no no"])
    }

    @Test func edgePunctuationIsTrimmed() {
        let spans = Candidates.spans(of: ["say", "hello.", "you're", "x.com"])
        #expect(spans.contains("say hello"))
        #expect(!spans.contains("hello."))
        #expect(spans.contains("you're x.com"))
    }

    @Test func spansStopAtEightWords() {
        let words = (1...10).map { "w\($0)" }
        #expect(Candidates.spans(of: words).map { $0.split(separator: " ").count }.max() == 8)
    }

    @Test func onlyTheLastThirtyWordsCount() {
        let words = (1...40).map { "w\($0)" }
        let spans = Candidates.spans(of: words)
        #expect(!spans.contains("w10"))
        #expect(spans.contains("w11"))
    }
}

@Suite struct SiteTests {
    @Test(arguments: [
        ("x dot com", "https://x.com"),
        ("Stripe dot com", "https://stripe.com"),
        ("youtube", "https://youtube.com"),
        ("wikipedia.org", "https://wikipedia.org"),
        ("g1 ponto com ponto br", "https://g1.com.br"),
    ])
    func spokenSiteBecomesURL(spoken: String, expected: String) {
        #expect(Site.url(from: spoken) == URL(string: expected))
    }

    @Test(arguments: ["", "what?", "x..com", "dot."])
    func garbageIsNotASite(spoken: String) {
        #expect(Site.url(from: spoken) == nil)
    }
}

@Suite struct CommandTests {
    @Test func readableDescriptions() {
        #expect(Command.openApp("Notes").description == "open Notes")
        #expect(Command.newItem.description == "new item")
        #expect(Command.openURL(URL(string: "https://x.com")!).description == "open https://x.com")
        #expect(Command.webSearch("norbert wiener").description == "search “norbert wiener”")
        #expect(Command.typeText("hello").description == "type “hello”")
    }
}

@Suite struct InstalledAppsTests {
    @Test func listsAppBundlesAcrossFoldersOnce() throws {
        let fm = FileManager.default
        let a = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let b = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: a); try? fm.removeItem(at: b) }
        for dir in ["Foo.app", "Bar.app"] { try fm.createDirectory(at: a.appendingPathComponent(dir), withIntermediateDirectories: true) }
        try fm.createDirectory(at: b.appendingPathComponent("Foo.app"), withIntermediateDirectories: true)
        try Data().write(to: a.appendingPathComponent("notes.txt"))
        #expect(InstalledApps.names(in: [a.path, b.path, "/nope/missing"]) == ["Bar", "Foo"])
    }
}
