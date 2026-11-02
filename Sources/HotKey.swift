import Carbon

/// Global "hide now" hotkey (Control-Option-Command-H). Carbon hotkeys need no
/// Accessibility permission.
enum HotKey {
    static var handler: (() -> Void)?
    private static var ref: EventHotKeyRef?

    static func register() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKey.handler?() }
            return noErr
        }, 1, &spec, nil, nil)
        let id = EventHotKeyID(signature: OSType(0x4544_4C47), id: 1)
        RegisterEventHotKey(UInt32(kVK_ANSI_H), UInt32(cmdKey | optionKey | controlKey), id,
                            GetApplicationEventTarget(), 0, &ref)
    }
}
