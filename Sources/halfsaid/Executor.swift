import AppKit
import ApplicationServices
import HalfsaidCore

/// Runs commands on this Mac. Typing and ⌘N need Accessibility access for the app running halfsaid.
@MainActor
struct Executor {
    // Calibration knob: time for a new note or document to take keyboard focus after ⌘N.
    static let newItemSettles: Duration = .milliseconds(300)

    let apps: [String: URL]
    let dryRun: Bool

    enum Failure: Error, CustomStringConvertible {
        case unknownApp(String)
        case needsAccessibility
        case keyboard

        var description: String {
            switch self {
            case .unknownApp(let name): "no installed app named \(name)"
            case .needsAccessibility: "ℹ︎ Typing and ⌘N need Accessibility access for the app running halfsaid (your terminal): System Settings → Privacy & Security → Accessibility. Opening apps and sites works without it."
            case .keyboard: "could not create a keyboard event"
            }
        }
    }

    /// Returns what went wrong, or nil.
    func run(_ command: Command) async -> String? {
        guard !dryRun else {
            out("   dry run: would \(command)\n")
            return nil
        }
        do {
            switch command {
            case .openApp(let name):
                try await open(name)
            case .newItem:
                try press(key: 0x2D, flags: .maskCommand)  // ⌘N. ponytail: physical N key; some non-QWERTY layouts differ
                try await Task.sleep(for: Self.newItemSettles)
            case .typeText(let text):
                try type(text)
            case .openURL, .webSearch:
                if let url = command.webURL { try await browse(url) }
            }
            return nil
        } catch {
            out("⚠︎ \(command): \(error)\n")
            return "\(error)"
        }
    }

    private func open(_ name: String) async throws {
        guard let url = apps[name] else { throw Failure.unknownApp(name) }
        let app = try await NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        for _ in 0..<40 {  // up to 2 s, so the next keystrokes land in it
            if app.isActive { return }
            try await Task.sleep(for: .milliseconds(50))
        }
    }

    /// Opens in the frontmost app when it is a browser ("open safari and search…"), else the default browser.
    private func browse(_ url: URL) async throws {
        let browsers = NSWorkspace.shared.urlsForApplications(toOpen: URL(string: "https://example.com")!)
        if let front = NSWorkspace.shared.frontmostApplication?.bundleURL, browsers.contains(front) {
            _ = try await NSWorkspace.shared.open([url], withApplicationAt: front, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    private func type(_ text: String) throws {
        guard AXIsProcessTrusted() else { throw Failure.needsAccessibility }
        for chunk in Keystrokes.chunks(text) {
            let units = Array(chunk.utf16)
            try post(key: 0) { $0.keyboardSetUnicodeString(stringLength: units.count, unicodeString: units) }
        }
    }

    private func press(key: CGKeyCode, flags: CGEventFlags) throws {
        guard AXIsProcessTrusted() else { throw Failure.needsAccessibility }
        try post(key: key) { $0.flags = flags }
    }

    private func post(key: CGKeyCode, configure: (CGEvent) -> Void) throws {
        let source = CGEventSource(stateID: .hidSystemState)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: down) else { throw Failure.keyboard }
            configure(event)
            event.post(tap: .cghidEventTap)
        }
    }
}
