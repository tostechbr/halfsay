import AppKit
import ApplicationServices
import Foundation
import HalfsayCore

@main @MainActor struct Halfsay {
    static let usage = """
    usage: halfsay [--text "sentence"] [--dry-run] [--log] [--locale en-US] [--wpm 160]

      (no --text)  menu bar app: floating bar, ⌥Space to start or stop listening
      --text       feed a sentence at speaking pace instead of the mic (terminal only)
      --dry-run    print commands instead of running them
      --log        keep a local trace in ~/Library/Logs/halfsay (everything the mic hears)
      --locale     speech language, e.g. en-US (default: this Mac's language)
      --wpm        speaking pace for --text, in words per minute
    """

    static func main() {
        let options: Options
        do {
            options = try Options(CommandLine.arguments.dropFirst())
        } catch {
            fail("\(error)\n\n\(usage)", code: 2)
        }
        let key = APIKey.load()
        let apps = InstalledApps.urls()
        let log: EventLog?
        do {
            log = options.log ? try EventLog() : nil
        } catch {
            fail("Could not create the log: \(error)")
        }
        if let log { out("📝 logging to \(log.url.path)\n") }
        log?.write("start", ["mode": options.text == nil ? "app" : "text", "dry_run": options.dryRun, "apps": apps.count])
        let session = Session(client: JevClient(apiKey: key ?? ""), apps: apps,
                              executor: Executor(apps: apps, dryRun: options.dryRun), log: log)

        if let text = options.text {
            guard key != nil else { fail("Set TYPESAFE_API_KEY or run `make key` (get a key at https://console.typesafe.ai).") }
            if !options.dryRun, !AXIsProcessTrusted() { out(Executor.Failure.needsAccessibility.description + "\n") }
            Task {
                await session.replay(text, wpm: options.wpm)
                exit(0)
            }
            dispatchMain()
        }

        let model = BarModel()
        session.bar = model
        let controller = AppController(session: session, model: model, options: options, hints: apps.keys.sorted(),
                                       hasKey: key != nil, log: log)
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.delegate = controller
        withExtendedLifetime(controller) { app.run() }
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
