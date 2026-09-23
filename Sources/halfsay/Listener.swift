import AVFoundation
import Speech

/// Microphone → Apple speech recognition, with partial results.
@MainActor
final class Listener {
    var onPartial: (String) -> Void = { _ in }
    var onEnded: () -> Void = {}
    let onDevice: Bool
    let language: String

    private let recognizer: SFSpeechRecognizer
    private let hints: [String]
    private let audio = AVAudioEngine()
    private let sink = BufferSink()
    private var task: SFSpeechRecognitionTask?
    private var generation = 0
    private var running = false

    /// `nil` locale: this Mac's language.
    init?(locale: Locale?, hints: [String]) {
        let recognizer = if let locale { SFSpeechRecognizer(locale: locale) } else { SFSpeechRecognizer() }
        guard let recognizer, recognizer.isAvailable else { return nil }
        self.recognizer = recognizer
        language = recognizer.locale.identifier
        self.hints = Array(hints.prefix(100))  // app names help it hear "Photo Booth", "Arc"
        onDevice = recognizer.supportsOnDeviceRecognition
    }

    nonisolated static func authorize() async -> Bool {
        let speech = await withCheckedContinuation { (done: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            // @Sendable: TCC calls back on its own queue; a main-actor closure traps there (dispatch_assert_queue_fail)
            SFSpeechRecognizer.requestAuthorization { @Sendable status in done.resume(returning: status) }
        }
        let microphone = await AVCaptureDevice.requestAccess(for: .audio)
        return speech == .authorized && microphone
    }

    func start() throws {
        guard !running else { return }
        let input = audio.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0), block: sink.tap)
        audio.prepare()
        do {
            try audio.start()
        } catch {
            input.removeTap(onBus: 0)
            throw error
        }
        running = true
        restart()
    }

    func stop() {
        guard running else { return }
        running = false
        generation += 1  // a cancelled request still reporting is ignored
        task?.cancel()
        task = nil
        sink.request?.endAudio()
        sink.request = nil
        audio.inputNode.removeTap(onBus: 0)
        audio.stop()
    }

    /// A fresh recognition request per utterance keeps transcripts short.
    func restart() {
        guard running else { return }
        task?.cancel()
        generation += 1
        let current = generation
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = onDevice
        request.addsPunctuation = false
        request.contextualStrings = hints
        sink.request = request
        task = recognizer.recognitionTask(with: request) { @Sendable [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let ended = error != nil || (result?.isFinal ?? false)
            Task { @MainActor in self?.received(text, ended: ended, generation: current) }
        }
    }

    private func received(_ text: String?, ended: Bool, generation: Int) {
        guard generation == self.generation else { return }  // a cancelled request still reporting
        if let text { onPartial(text) }
        if ended { onEnded() }
    }
}

/// Audio-thread side: hands microphone buffers to whichever request is current.
final class BufferSink: @unchecked Sendable {
    private let lock = NSLock()
    private var current: SFSpeechAudioBufferRecognitionRequest?

    var request: SFSpeechAudioBufferRecognitionRequest? {
        get { lock.withLock { current } }
        set { lock.withLock { current = newValue } }
    }

    var tap: AVAudioNodeTapBlock {
        { [self] buffer, _ in request?.append(buffer) }
    }
}
