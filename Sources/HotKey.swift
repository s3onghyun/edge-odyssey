import Carbon

/// Global Control-Option-Command hotkeys: H hides now, F toggles focus mode. Carbon hotkeys
/// need no Accessibility permission.
enum HotKey {
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var refs: [EventHotKeyRef?] = []

    /// Control-Option-Command plus `key` (a kVK_ code).
    static func register(_ key: Int, _ handler: @escaping () -> Void) {
        if handlers.isEmpty {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
                var hk = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                  nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
                let id = hk.id
                DispatchQueue.main.async { HotKey.handlers[id]?() }
                return noErr
            }, 1, &spec, nil, nil)
        }
        let id = UInt32(handlers.count + 1)
        handlers[id] = handler
        var ref: EventHotKeyRef?
        RegisterEventHotKey(UInt32(key), UInt32(cmdKey | optionKey | controlKey), EventHotKeyID(signature: OSType(0x4544_4C47), id: id),
                            GetApplicationEventTarget(), 0, &ref)
        refs.append(ref)
    }
}
