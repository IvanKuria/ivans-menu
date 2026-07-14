import AppKit
import Carbon.HIToolbox

final class GlobalHotKey {
    private var ref: EventHotKeyRef?
    private let onToggle: () -> Void
    private var handler: EventHandlerRef?

    init(onToggle: @escaping () -> Void) {
        self.onToggle = onToggle
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: OSType(kEventHotKeyPressed))
        let ptr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, ctx in
            let me = Unmanaged<GlobalHotKey>.fromOpaque(ctx!).takeUnretainedValue()
            me.onToggle()
            return noErr
        }, 1, &spec, ptr, &handler)

        let id = EventHotKeyID(signature: OSType(0x494D4E55), id: 1) // 'IMNU'
        RegisterEventHotKey(UInt32(kVK_Space), UInt32(optionKey),
                            id, GetApplicationEventTarget(), 0, &ref)
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}
