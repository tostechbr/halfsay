import Carbon.HIToolbox

/// ⌥Space from any app. Carbon hot keys need no Accessibility or Input Monitoring permission.
@MainActor
final class Hotkey {
    struct Taken: Error {}

    private var action: () -> Void = {}
    private var reference: EventHotKeyRef?

    func register(_ action: @escaping () -> Void) throws {
        self.action = action
        var pressed = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let hotkey = Unmanaged<Hotkey>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { hotkey.action() }  // Carbon delivers hot keys on the main thread
            return noErr
        }, 1, &pressed, Unmanaged.passUnretained(self).toOpaque(), nil)
        let id = EventHotKeyID(signature: OSType(0x6861_6C66), id: 1)  // "half"
        let registered = RegisterEventHotKey(UInt32(kVK_Space), UInt32(optionKey), id, GetApplicationEventTarget(), 0, &reference)
        guard installed == noErr, registered == noErr else { throw Taken() }
    }
}
