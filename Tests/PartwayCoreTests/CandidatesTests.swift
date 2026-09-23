import Foundation
import Testing
@testable import PartwayCore

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
