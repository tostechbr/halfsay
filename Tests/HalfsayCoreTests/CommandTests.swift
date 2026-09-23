import Foundation
import Testing
@testable import HalfsayCore

@Suite struct SiteTests {
    @Test(arguments: [
        ("x dot com", "https://x.com"),
        ("Stripe dot com", "https://stripe.com"),
        ("youtube", "https://youtube.com"),
        ("wikipedia.org", "https://wikipedia.org"),
        ("g1 ponto com ponto br", "https://g1.com.br"),
        ("meu site do LinkedIn", "https://linkedin.com"),
        ("my website on github", "https://github.com"),
        ("linkedin no google", "https://linkedin.com"),
        ("meu linkedin pelo chrome", "https://linkedin.com"),
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
