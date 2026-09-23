import AppKit
import ApplicationServices
import PartwayCore

/// The menu bar app: the floating bar, ⌥Space to start or stop listening, and a menu to quit.
@MainActor
final class AppController: NSObject, NSApplicationDelegate {
    private let session: Session
    private let model: BarModel
    private let options: Options
    private let hints: [String]
    private var hasKey: Bool
    private let log: EventLog?
    private let hotkey = Hotkey()
    private var panel: BarPanel?
    private var statusItem: NSStatusItem?
    private var toggleItem: NSMenuItem?
    private var listener: Listener?
    private var listening = false
    private var askedForAccessibility = false

    init(session: Session, model: BarModel, options: Options, hints: [String], hasKey: Bool, log: EventLog?) {
        self.session = session
        self.model = model
        self.options = options
        self.hints = hints
        self.hasKey = hasKey
        self.log = log
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let panel = BarPanel(model: model)
        panel.orderFrontRegardless()
        self.panel = panel
        model.toggle = { [weak self] in self?.toggle() }
        model.drag = { [weak panel] phase in panel?.drag(phase) }
        statusItem = makeStatusItem()
        showState()
        session.onUtteranceEnd = { [weak self] in
            guard let self, self.listening else { return }
            self.listener?.restart()
        }
        do {
            try hotkey.register { [weak self] in self?.toggle() }
        } catch {
            model.notice = "⌥Space is taken by another app: use the menu bar icon."
        }
        if !hasKey { model.notice = "No Jev key yet: press ⌥Space to add yours." }
    }

    /// Asks for the key in a dialog: an app downloaded from Releases has no `.env` and no `make key`.
    @objc private func promptForKey() {
        NSApp.activate()  // the panel never takes focus, so the dialog brings the app forward to accept typing
        let alert = NSAlert()
        alert.messageText = "Paste your Jev API key"
        alert.informativeText = "Get one at console.typesafe.ai. It is saved only on this Mac, readable only by you, in ~/.config/partway/api-key."
        let field = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
        alert.accessoryView = field
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = field
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        do {
            try APIKey.save(field.stringValue)
            session.use(apiKey: field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines))
            hasKey = true
            model.notice = nil
        } catch {
            model.notice = "The key was not saved: \(error)"
        }
    }

    @objc func toggle() {
        if listening {
            stop()
        } else {
            Task { await start() }
        }
    }

    private func start() async {
        if !hasKey { promptForKey() }
        guard hasKey else { return }
        guard await Listener.authorize() else {
            model.notice = "partway needs Microphone and Speech Recognition: System Settings → Privacy & Security."
            return
        }
        if listener == nil {
            guard let made = Listener(locale: options.locale, hints: hints) else {
                model.notice = "No speech recognizer for this language."
                return
            }
            made.onPartial = { [weak self] in self?.session.heard($0) }
            made.onEnded = { [weak self] in self?.session.recognizerEnded() }
            listener = made
        }
        guard let listener else { return }
        do {
            try listener.start()
        } catch {
            model.notice = "The microphone did not start: \(error)"
            return
        }
        listening = true
        model.listening = true
        model.notice = nil
        showState()
        log?.write("listening", ["language": listener.language, "on_device": listener.onDevice])
        out("🎙 listening in \(listener.language), transcribed \(listener.onDevice ? "on this Mac" : "by Apple servers")\n")
        if !options.dryRun, !askedForAccessibility {
            askedForAccessibility = true
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        }
    }

    private func stop() {
        listening = false  // before the session ends the utterance, so it does not restart the recognizer
        model.listening = false
        listener?.stop()
        session.stop()
        log?.write("stopped")
        showState()
    }

    /// The menu bar icon and menu say whether partway is listening.
    private func showState() {
        statusItem?.button?.image = NSImage(systemSymbolName: listening ? "mic.fill" : "mic.slash",
                                            accessibilityDescription: listening ? "partway is listening" : "partway is paused")
        toggleItem?.title = listening ? "Pause listening (⌥Space)" : "Start listening (⌥Space)"
    }

    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "waveform", accessibilityDescription: "partway")
        let menu = NSMenu()
        let toggleItem = NSMenuItem(title: "Start listening (⌥Space)", action: #selector(toggle), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        self.toggleItem = toggleItem
        let keyItem = NSMenuItem(title: "Set Jev API key…", action: #selector(promptForKey), keyEquivalent: "")
        keyItem.target = self
        menu.addItem(keyItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit partway", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.menu = menu
        return item
    }
}
