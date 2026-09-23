import Foundation
import Testing
@testable import HalfsaidCore

private func decision(_ action: Action, _ confidence: Double = 1, app: String? = nil, appP: Double = 1, arg: String? = nil,
                      opensApp: Double = 0) -> Decision {
    Decision(action: action, confidence: confidence, app: app, appProbability: app == nil ? 0 : appP, argument: arg, opensApp: opensApp)
}

@Suite struct EngineTests {
    @Test func closedActionFiresAfterTwoAgreeingPartials() {
        var engine = Engine()
        let r1 = engine.hear("open the notes")!
        #expect(engine.receive(decision(.openApp, app: "Notes"), for: r1).command == nil)
        let r2 = engine.hear("open the notes app")!
        #expect(engine.receive(decision(.openApp, app: "Notes"), for: r2).command == .openApp("Notes"))
    }

    @Test func shakyPartialResetsTheStreak() {
        var engine = Engine()
        _ = engine.receive(decision(.openApp, app: "Notes"), for: engine.hear("open notes")!)
        _ = engine.receive(decision(.openApp, 0.5, app: "Notes"), for: engine.hear("open notes for")!)
        #expect(engine.receive(decision(.openApp, app: "Notes"), for: engine.hear("open notes for me")!).command == nil)
    }

    @Test func changingTargetRestartsTheStreak() {
        var engine = Engine()
        _ = engine.receive(decision(.openApp, app: "Notes"), for: engine.hear("open notes")!)
        #expect(engine.receive(decision(.openApp, app: "Safari"), for: engine.hear("open notes no safari")!).command == nil)
    }

    @Test func unsureAppNeverFiresEarly() {
        var engine = Engine()
        _ = engine.receive(decision(.openApp, app: "Notes", appP: 0.6), for: engine.hear("open no")!)
        #expect(engine.receive(decision(.openApp, app: "Notes", appP: 0.6), for: engine.hear("open no tes")!).command == nil)
    }

    @Test func sureAppOpensAtLowerConfidence() {
        var engine = Engine()
        _ = engine.receive(decision(.openApp, 0.81, app: "Notes"), for: engine.hear("abre as notas")!)
        #expect(engine.receive(decision(.openApp, 0.82, app: "Notes"), for: engine.hear("abre as notas e")!).command == .openApp("Notes"))
    }

    @Test func appBelowSureWaitsForThePause() {
        var engine = Engine()
        _ = engine.receive(decision(.openApp, app: "Google Chrome", appP: 0.9), for: engine.hear("abre o google")!)
        #expect(engine.receive(decision(.openApp, app: "Google Chrome", appP: 0.9), for: engine.hear("abre o google chrome")!).command == nil)
        #expect(engine.pause().command == .openApp("Google Chrome"))
    }

    @Test func yesNoOpensAppFiresWhenASecondCommandSplitsTheChoice() {
        var engine = Engine()
        _ = engine.receive(decision(.typeText, 0.5, app: "Notes", opensApp: 0.93), for: engine.hear("abre as notas e digita")!)
        #expect(engine.receive(decision(.typeText, 0.46, app: "Notes", opensApp: 0.91), for: engine.hear("abre as notas e digita eu")!).command == .openApp("Notes"))
    }

    @Test func yesNoOpensAppStillNeedsASureApp() {
        var engine = Engine()
        _ = engine.receive(decision(.none, app: "Notes", appP: 0.7, opensApp: 0.95), for: engine.hear("abre as no")!)
        #expect(engine.receive(decision(.none, app: "Notes", appP: 0.7, opensApp: 0.95), for: engine.hear("abre as not")!).command == nil)
    }

    @Test func newItemStillNeedsHighConfidence() {
        var engine = Engine()
        _ = engine.receive(decision(.newItem, 0.81), for: engine.hear("cria uma")!)
        #expect(engine.receive(decision(.newItem, 0.82), for: engine.hear("cria uma nota")!).command == nil)
    }

    @Test func newItemFiresEarlyWithoutAnApp() {
        var engine = Engine()
        _ = engine.receive(decision(.newItem), for: engine.hear("create a new")!)
        #expect(engine.receive(decision(.newItem, app: "Notes"), for: engine.hear("create a new note")!).command == .newItem)
    }

    @Test func openTextWaitsForThePause() {
        var engine = Engine()
        #expect(engine.receive(decision(.webSearch, arg: "norbert"), for: engine.hear("google norbert")!).command == nil)
        #expect(engine.receive(decision(.webSearch, arg: "norbert wiener"), for: engine.hear("google norbert wiener")!).command == nil)
        #expect(engine.pause().command == .webSearch("norbert wiener"))
    }

    @Test func pauseBeforeTheAnswerFiresWhenItArrives() {
        var engine = Engine()
        let request = engine.hear("type hello")!
        #expect(engine.pause().command == nil)
        #expect(engine.receive(decision(.typeText, arg: "hello"), for: request).command == .typeText("hello"))
    }

    @Test func pauseStillNeedsConfidenceAndArgument() {
        var engine = Engine()
        _ = engine.receive(decision(.webSearch, 0.6, arg: "lisbon"), for: engine.hear("search lisbon")!)
        #expect(engine.pause().command == nil)
        _ = engine.receive(decision(.webSearch), for: engine.hear("search lisbon um")!)
        #expect(engine.pause().command == nil)
        _ = engine.receive(decision(.openApp, app: "Notes", appP: 0.5), for: engine.hear("search lisbon um notes")!)
        #expect(engine.pause().command == nil)
    }

    @Test func pauseFiresAShortClosedCommand() {
        var engine = Engine()
        _ = engine.receive(decision(.openApp, app: "Notes"), for: engine.hear("notes")!)
        #expect(engine.pause().command == .openApp("Notes"))
    }

    @Test func spokenSiteBecomesURL() {
        var engine = Engine()
        _ = engine.receive(decision(.openURL, arg: "x dot com"), for: engine.hear("open x dot com")!)
        #expect(engine.pause().command == .openURL(URL(string: "https://x.com")!))
    }

    @Test func noneNeverFires() {
        var engine = Engine()
        _ = engine.receive(decision(.none), for: engine.hear("can you")!)
        #expect(engine.receive(decision(.none), for: engine.hear("can you um")!).command == nil)
        #expect(engine.pause().command == nil)
    }

    @Test func firedWordsAreConsumedSoTheNextCommandChains() {
        var engine = Engine()
        _ = engine.receive(decision(.openApp, app: "Notes"), for: engine.hear("open notes")!)
        let step = engine.receive(decision(.openApp, app: "Notes"), for: engine.hear("open notes and")!)
        #expect(step.command == .openApp("Notes"))
        #expect(step.request?.tail == ["and"])  // the open ends at the app's name
        #expect(engine.hear("open notes and create a new note")?.tail == ["and", "create", "a", "new", "note"])
    }

    @Test func fireSendsTheRemainingTailRightAway() {
        var engine = Engine()
        let r1 = engine.hear("open notes")!
        let r2 = engine.hear("open notes app")!
        let r3 = engine.hear("open notes app new note")!
        _ = engine.receive(decision(.openApp, app: "Notes"), for: r1)
        let step = engine.receive(decision(.openApp, app: "Notes"), for: r2)
        #expect(step.command == .openApp("Notes"))
        #expect(step.request?.tail == ["new", "note"])
        #expect(engine.receive(decision(.openApp, app: "Notes"), for: r3).command == nil)
    }

    @Test func followUpSentWhileSilentIsJudgedAsPaused() throws {
        var engine = Engine()
        let r1 = engine.hear("open notes")!
        let r2 = engine.hear("open notes app")!
        _ = engine.hear("open notes app type hi")
        _ = engine.pause()
        _ = engine.receive(decision(.openApp, app: "Notes"), for: r1)
        let step = engine.receive(decision(.openApp, app: "Notes"), for: r2)
        #expect(step.command == .openApp("Notes"))
        let followUp = try #require(step.request)
        #expect(followUp.tail == ["type", "hi"])
        #expect(engine.receive(decision(.typeText, arg: "hi"), for: followUp).command == .typeText("hi"))
    }

    @Test func openTextKeepsTheCommandChainedAfterIt() throws {
        var engine = Engine()
        _ = engine.receive(decision(.webSearch, arg: "cake recipes"), for: engine.hear("search cake recipes and open notes")!)
        let step = engine.pause()
        #expect(step.command == .webSearch("cake recipes"))
        let followUp = try #require(step.request)
        #expect(followUp.tail == ["and", "open", "notes"])
        #expect(engine.receive(decision(.openApp, app: "Notes"), for: followUp).command == .openApp("Notes"))
    }

    @Test func argumentAtTheEndUsesTheWholeTail() {
        var engine = Engine()
        _ = engine.receive(decision(.webSearch, arg: "norbert wiener"), for: engine.hear("google norbert wiener")!)
        #expect(engine.pause().request == nil)
    }

    @Test func appCommandSaidAtOnceKeepsTheNextCommand() throws {
        var engine = Engine()
        engine.appAliases = ["Notes": ["Notes", "Notas"]]
        let request = engine.hear("abre as notas e digita oi")!
        _ = engine.pause()
        let step = engine.receive(decision(.openApp, app: "Notes"), for: request)
        #expect(step.command == .openApp("Notes"))
        let followUp = try #require(step.request)
        #expect(followUp.tail == ["e", "digita", "oi"])
    }

    @Test func appNamedByItsFirstWordStillBoundsTheCommand() {
        #expect(Engine.wordsUsed(by: .openApp("Google Chrome"), argument: nil, aliases: ["Google Chrome"],
                                 in: ["abre", "o", "google", "e", "pesquisa", "bolo"]) == 3)
    }

    @Test func accentsDoNotHideTheApp() {
        #expect(Engine.wordsUsed(by: .openApp("Calendar"), argument: nil, aliases: ["Calendar", "Calendário"],
                                 in: ["abre", "o", "calendario", "agora"]) == 3)
    }

    @Test func unknownAppMentionUsesTheWholeTail() {
        #expect(Engine.wordsUsed(by: .openApp("Visual Studio Code"), argument: nil, aliases: ["Visual Studio Code"],
                                 in: ["abre", "o", "vscode", "e", "digita"]) == 5)
    }

    @Test func lateOlderAnswerIsIgnored() {
        var engine = Engine()
        let r1 = engine.hear("open notes")!
        let r2 = engine.hear("open notes app")!
        _ = engine.receive(decision(.openApp, app: "Notes"), for: r2)
        #expect(engine.receive(decision(.openApp, app: "Notes"), for: r1).command == nil)
        #expect(engine.receive(decision(.openApp, app: "Notes"), for: engine.hear("open notes app please")!).command == .openApp("Notes"))
    }

    @Test func unchangedTranscriptSendsNothing() {
        var engine = Engine()
        #expect(engine.hear("") == nil)
        #expect(engine.hear("open") != nil)
        #expect(engine.hear("open") == nil)
    }

    @Test func resetStartsAFreshUtterance() {
        var engine = Engine()
        let old = engine.hear("open notes")!
        engine.reset()
        #expect(engine.receive(decision(.openApp, app: "Notes"), for: old).command == nil)
        #expect(engine.hear("open safari")?.tail == ["open", "safari"])
        #expect(engine.consumed == 0)
    }
}
