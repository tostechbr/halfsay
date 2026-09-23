import ApplicationServices
import Foundation
import HalfsaidCore

@main @MainActor struct Halfsaid {
    static let usage = """
    usage: halfsaid [--text "sentence"] [--dry-run] [--log] [--locale en-US] [--wpm 160]

      (no --text)  listen on the microphone and act
      --text       feed a sentence at speaking pace instead of the mic
      --dry-run    print commands instead of running them
      --log        keep a local trace in ~/Library/Logs/halfsaid (everything the mic hears)
      --locale     speech language, e.g. en-US (default: this Mac's language)
      --wpm        speaking pace for --text, in words per minute
    """

    static func main() async {
        let options: Options
        do {
            options = try Options(CommandLine.arguments.dropFirst())
        } catch {
            fail("\(error)\n\n\(usage)", code: 2)
        }
        guard let key = ProcessInfo.processInfo.environment["TYPESAFE_API_KEY"], !key.isEmpty else {
            fail("Set TYPESAFE_API_KEY (get one at https://console.typesafe.ai).")
        }
        let apps = InstalledApps.urls()
        let log: EventLog?
        do {
            log = options.log ? try EventLog() : nil
        } catch {
            fail("Could not create the log: \(error)")
        }
        if let log { out("📝 logging to \(log.url.path)\n") }
        log?.write("start", ["mode": options.text == nil ? "mic" : "text", "dry_run": options.dryRun, "apps": apps.count])
        let session = Session(client: JevClient(apiKey: key), apps: apps, executor: Executor(apps: apps, dryRun: options.dryRun), log: log)
        if let text = options.text {
            if !options.dryRun, !AXIsProcessTrusted() { out(Executor.Failure.needsAccessibility.description + "\n") }
            await session.replay(text, wpm: options.wpm)
        } else {
            await listen(session, options: options, hints: apps.keys.sorted(), log: log)
        }
    }

    static func listen(_ session: Session, options: Options, hints: [String], log: EventLog?) async {
        guard await Listener.authorize() else {
            fail("halfsaid needs Microphone and Speech Recognition access: System Settings → Privacy & Security.")
        }
        guard let listener = Listener(locale: options.locale, hints: hints) else {
            fail("No speech recognizer available for \(options.locale?.identifier ?? "this Mac's language").")
        }
        if !options.dryRun, !AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) {
            out(Executor.Failure.needsAccessibility.description + "\n")
        }
        listener.onPartial = { session.heard($0) }
        listener.onEnded = { session.recognizerEnded() }
        session.onUtteranceEnd = { listener.restart() }
        do {
            try listener.start()
        } catch {
            fail("The microphone did not start: \(error)")
        }
        log?.write("listening", ["language": listener.language, "on_device": listener.onDevice])
        out("🎙 listening in \(listener.language), transcribed \(listener.onDevice ? "on this Mac" : "by Apple servers") · Ctrl-C to quit\n")
        while true { try? await Task.sleep(for: .seconds(3600)) }
    }
}

struct Options {
    var text: String?
    var dryRun = false
    var log = false
    var locale: Locale?
    var wpm = 160.0

    struct Invalid: Error, CustomStringConvertible { let description: String }

    init(_ arguments: ArraySlice<String>) throws {
        var arguments = arguments
        while let flag = arguments.popFirst() {
            switch flag {
            case "--dry-run": dryRun = true
            case "--log": log = true
            case "--text": text = try Self.value(of: flag, from: &arguments)
            case "--locale": locale = Locale(identifier: try Self.value(of: flag, from: &arguments))
            case "--wpm":
                guard let wpm = Double(try Self.value(of: flag, from: &arguments)), wpm > 0 else {
                    throw Invalid(description: "--wpm needs a positive number")
                }
                self.wpm = wpm
            default: throw Invalid(description: "unknown option \(flag)")
            }
        }
    }

    private static func value(of flag: String, from arguments: inout ArraySlice<String>) throws -> String {
        guard let value = arguments.popFirst(), !value.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw Invalid(description: "\(flag) needs a value")
        }
        return value
    }
}

/// Unbuffered stdout: the live line is redrawn in place.
func out(_ text: String) {
    FileHandle.standardOutput.write(Data(text.utf8))
}

func fail(_ message: String, code: Int32 = 1) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(code)
}
