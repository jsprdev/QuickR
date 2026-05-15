import AppKit
import Carbon.HIToolbox

/// Stable identifiers for each registered hotkey slot. The raw value is the Carbon
/// `EventHotKeyID.id` we hand to the OS — must be > 0.
enum HotKeySlot: UInt32 {
    case drag = 1
    case smart = 2
}

struct HotKeyBinding: Equatable, Codable {
    let keyCode: UInt32
    let modifiers: UInt32
    /// Pre-rendered glyph for the key (e.g. "8", "A", "F5"). Stored so display
    /// doesn't have to round-trip through the keyboard layout API.
    let glyph: String
}

final class HotKeyManager {
    private struct Registration {
        let ref: EventHotKeyRef
        let handler: () -> Void
    }

    private var registrations: [UInt32: Registration] = [:]
    private var handlerRef: EventHandlerRef?

    deinit { unregisterAll() }

    func register(slot: HotKeySlot, binding: HotKeyBinding, onTrigger: @escaping () -> Void) {
        unregister(slot: slot)
        installHandlerIfNeeded()

        let id = EventHotKeyID(signature: 0x51_4B_52_31, id: slot.rawValue)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            binding.keyCode,
            binding.modifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else { return }
        registrations[slot.rawValue] = Registration(ref: ref, handler: onTrigger)
    }

    func unregister(slot: HotKeySlot) {
        if let reg = registrations.removeValue(forKey: slot.rawValue) {
            UnregisterEventHotKey(reg.ref)
        }
    }

    func unregisterAll() {
        for (_, reg) in registrations {
            UnregisterEventHotKey(reg.ref)
        }
        registrations.removeAll()
        if let h = handlerRef {
            RemoveEventHandler(h)
            handlerRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData -> OSStatus in
                guard let userData, let eventRef else { return noErr }
                var id = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &id
                )
                guard status == noErr else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                let handler = manager.registrations[id.id]?.handler
                DispatchQueue.main.async { handler?() }
                return noErr
            },
            1, &spec, selfPtr, &handlerRef
        )
    }
}
