import Carbon.HIToolbox
import Foundation

final class GlobalHotkey {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private let keyCode: UInt32
    private let modifiers: UInt32
    private let onTrigger: () -> Void

    init(keyCode: UInt32, modifiers: UInt32, onTrigger: @escaping () -> Void) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.onTrigger = onTrigger
    }

    deinit {
        unregister()
    }

    func register() {
        guard hotKeyRef == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let pointer = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let userData, let eventRef else { return noErr }
                let hotkey = Unmanaged<GlobalHotkey>.fromOpaque(userData).takeUnretainedValue()

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }
                if Thread.isMainThread {
                    hotkey.onTrigger()
                } else {
                    DispatchQueue.main.async { hotkey.onTrigger() }
                }
                return noErr
            },
            1,
            &eventType,
            pointer,
            &eventHandlerRef
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x4B43_4C50), id: UInt32(1))
        RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }
}
