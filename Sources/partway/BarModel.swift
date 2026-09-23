import Combine
import PartwayCore

/// What the floating bar shows. Session writes it, BarView draws it.
@MainActor
final class BarModel: ObservableObject {
    struct Fired: Identifiable {
        let id: Int
        let command: String
        var lead: String?
    }

    @Published var listening = false
    /// Expanded while you talk (Jev's read below the pill); collapses when the utterance ends.
    @Published var expanded = false
    @Published var words: [SpokenWord] = []
    @Published var decision: Decision?
    @Published var fired: [Fired] = []
    /// A command just fired: the chip turns yellow until the next answer.
    @Published var flash = false
    @Published var paused = false
    /// Something the person must fix (permissions, key). Shown while the bar is idle.
    @Published var notice: String?

    enum Drag { case moved, ended }
    /// Set by the app: the bar's play/pause button and its drag-to-move.
    var toggle: () -> Void = {}
    var drag: (Drag) -> Void = { _ in }

    private var nextID = 0

    func heard(_ words: [SpokenWord]) {
        if !expanded { fired = [] }  // a new utterance starts clean
        self.words = words
        expanded = true
        paused = false
    }

    func answered(_ decision: Decision) {
        self.decision = decision
        flash = false
    }

    func fire(_ command: Command, words: [SpokenWord]) {
        nextID += 1
        fired.append(Fired(id: nextID, command: command.description))
        self.words = words
        flash = true
    }

    func finish(leads: [String]) {
        for (index, lead) in leads.enumerated() where index < fired.count { fired[index].lead = lead }
        expanded = false
        decision = nil
        paused = false
        flash = false
    }
}
