import Foundation
import Testing
@testable import HalfsaidCore

@Suite struct CandidatesTests {
    @Test func everyContiguousSpanIsACandidate() {
        let spans = Candidates.spans(of: ["google", "search", "norbert", "wiener"])
        #expect(spans.count == 7)  // 10 spans minus the three starting with "search"
        #expect(!spans.contains("search norbert wiener"))
        #expect(spans.contains("norbert wiener"))
        #expect(spans.contains("google search norbert wiener"))
    }

    @Test func duplicatesAppearOnce() {
        #expect(Candidates.spans(of: ["ha", "ha", "ha"]) == ["ha", "ha ha", "ha ha ha"])
    }

    @Test func argumentsNeverStartWithTheCommandOrEndDangling() {
        let typed = Candidates.spans(of: ["digita", "ls"])
        #expect(typed == ["ls"])
        let search = Candidates.spans(of: ["receita", "de"])
        #expect(search == ["receita"])
        #expect(Candidates.spans(of: ["e", "digita", "bom", "dia"]).allSatisfy { !$0.hasPrefix("e ") && !$0.hasPrefix("digita") })
        #expect(Candidates.spans(of: ["type", "the", "meeting"]).contains("the meeting"))  // an article may start the text
    }

    @Test func commandWordsAndFillerAreNeverArguments() {
        #expect(Candidates.spans(of: ["e", "pesquisar"]).isEmpty)
        let spans = Candidates.spans(of: ["e", "pesquisar", "receita"])
        #expect(spans.contains("receita"))
        #expect(!spans.contains("pesquisar"))
        #expect(!spans.contains("e pesquisar"))
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
        ("meu site do LinkedIn", "https://linkedin.com"),
        ("my website on github", "https://github.com"),
    ])
    func spokenSiteBecomesURL(spoken: String, expected: String) {
        #expect(Site.url(from: spoken) == URL(string: expected))
    }

    @Test(arguments: ["", "what?", "x..com", "dot.", "meu site", "hacker news", "receita de bolo"])
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

    @Test func browserCommandsHaveAWebAddress() {
        #expect(Command.webSearch("pão de queijo").webURL?.absoluteString == "https://www.google.com/search?q=p%C3%A3o%20de%20queijo")
        #expect(Command.openURL(URL(string: "https://x.com")!).webURL == URL(string: "https://x.com"))
        #expect(Command.openApp("Notes").webURL == nil)
    }
}

@Suite struct KeystrokesTests {
    @Test func shortTextIsOneChunk() {
        #expect(Keystrokes.chunks("hello") == ["hello"])
    }

    @Test func longTextSplitsAtTwentyUnits() {
        #expect(Keystrokes.chunks(String(repeating: "a", count: 25)) == [String(repeating: "a", count: 20), "aaaaa"])
    }

    @Test func neverSplitsACharacter() {
        let family = "👨‍👩‍👧‍👦"  // one Character, 11 UTF-16 units
        #expect(Keystrokes.chunks(family + family) == [family, family])
    }

    @Test func emptyTextTypesNothing() {
        #expect(Keystrokes.chunks("").isEmpty)
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
        #expect(InstalledApps.urls(in: [a.path, b.path])["Foo"]?.path == a.appendingPathComponent("Foo.app").path)
        #expect(InstalledApps.aliases(for: InstalledApps.urls(in: [a.path]))["Foo"] == ["Foo"])
    }
}
