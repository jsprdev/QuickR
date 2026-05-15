import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class HotKeyStore: ObservableObject {
    static let shared = HotKeyStore()

    @Published private(set) var drag: HotKeyBinding?
    @Published private(set) var smart: HotKeyBinding?
    /// True while any recorder is active. AppDelegate listens to suspend hotkeys
    /// so the existing binding doesn't fire when the user is trying to record a new one.
    @Published var isRecording: Bool = false

    private static let initializedKey = "hotkey.initialized"
    private static let dragKey = "hotkey.drag"
    private static let smartKey = "hotkey.smart"

    private init() {
        let defaults = UserDefaults.standard
        if !defaults.bool(forKey: Self.initializedKey) {
            let initial = HotKeyBinding(
                keyCode: UInt32(kVK_ANSI_8),
                modifiers: UInt32(cmdKey | shiftKey),
                glyph: "8"
            )
            Self.persist(initial, key: Self.dragKey)
            defaults.set(true, forKey: Self.initializedKey)
            self.drag = initial
        } else {
            self.drag = Self.load(key: Self.dragKey)
        }
        self.smart = Self.load(key: Self.smartKey)
    }

    func set(_ binding: HotKeyBinding?, for slot: HotKeySlot) {
        switch slot {
        case .drag:
            drag = binding
            Self.persist(binding, key: Self.dragKey)
        case .smart:
            smart = binding
            Self.persist(binding, key: Self.smartKey)
        }
    }

    func binding(for slot: HotKeySlot) -> HotKeyBinding? {
        switch slot {
        case .drag: return drag
        case .smart: return smart
        }
    }

    private static func load(key: String) -> HotKeyBinding? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(HotKeyBinding.self, from: data)
    }

    private static func persist(_ binding: HotKeyBinding?, key: String) {
        if let binding, let data = try? JSONEncoder().encode(binding) {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}
