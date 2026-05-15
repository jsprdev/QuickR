import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class HotKeyRecorderModel: ObservableObject {
    @Published var isRecording = false
    private var monitor: Any?
    var onCapture: ((HotKeyBinding) -> Void)?
    var onCancel: (() -> Void)?

    deinit {
        // Direct cleanup (cannot hop to main actor from deinit on strict concurrency).
        if let monitor { NSEvent.removeMonitor(monitor) }
    }

    func start() {
        guard !isRecording else { return }
        isRecording = true
        HotKeyStore.shared.isRecording = true

        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self else { return event }

            if Int(event.keyCode) == kVK_Escape {
                self.cancel()
                return nil
            }

            let modifiers = HotKeyRecorderModel.carbonModifiers(from: event.modifierFlags)
            // Require at least one Cmd/Ctrl/Opt modifier — Shift-only is rejected
            // because it would clash with normal typing.
            let needsModifier = modifiers & UInt32(cmdKey | controlKey | optionKey)
            guard needsModifier != 0 else {
                NSSound.beep()
                return nil
            }

            let glyph = HotKeyRecorderModel.glyph(for: event)
            let binding = HotKeyBinding(
                keyCode: UInt32(event.keyCode),
                modifiers: modifiers,
                glyph: glyph
            )
            self.onCapture?(binding)
            self.stop()
            return nil
        }
    }

    func cancel() {
        onCancel?()
        stop()
    }

    func stop() {
        isRecording = false
        HotKeyStore.shared.isRecording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var m: UInt32 = 0
        if flags.contains(.command) { m |= UInt32(cmdKey) }
        if flags.contains(.shift)   { m |= UInt32(shiftKey) }
        if flags.contains(.option)  { m |= UInt32(optionKey) }
        if flags.contains(.control) { m |= UInt32(controlKey) }
        return m
    }

    static func glyph(for event: NSEvent) -> String {
        if let special = specialKeyGlyph(for: Int(event.keyCode)) { return special }
        // charactersIgnoringModifiers respects Shift for letters but ignores Cmd/Opt.
        // Upper-cased so "a" displays as "A" alongside the modifier glyphs.
        if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
            return chars.uppercased()
        }
        return "?"
    }

    private static func specialKeyGlyph(for keyCode: Int) -> String? {
        switch keyCode {
        case kVK_Return:        return "↩"
        case kVK_Tab:            return "⇥"
        case kVK_Space:          return "Space"
        case kVK_Delete:         return "⌫"
        case kVK_ForwardDelete:  return "⌦"
        case kVK_LeftArrow:      return "←"
        case kVK_RightArrow:     return "→"
        case kVK_UpArrow:        return "↑"
        case kVK_DownArrow:      return "↓"
        case kVK_Home:           return "↖"
        case kVK_End:            return "↘"
        case kVK_PageUp:         return "⇞"
        case kVK_PageDown:       return "⇟"
        case kVK_F1:  return "F1";  case kVK_F2:  return "F2"
        case kVK_F3:  return "F3";  case kVK_F4:  return "F4"
        case kVK_F5:  return "F5";  case kVK_F6:  return "F6"
        case kVK_F7:  return "F7";  case kVK_F8:  return "F8"
        case kVK_F9:  return "F9";  case kVK_F10: return "F10"
        case kVK_F11: return "F11"; case kVK_F12: return "F12"
        default: return nil
        }
    }
}

enum HotKeyFormatter {
    static func string(for binding: HotKeyBinding) -> String {
        var parts: [String] = []
        let m = binding.modifiers
        if m & UInt32(controlKey) != 0 { parts.append("⌃") }
        if m & UInt32(optionKey)  != 0 { parts.append("⌥") }
        if m & UInt32(shiftKey)   != 0 { parts.append("⇧") }
        if m & UInt32(cmdKey)     != 0 { parts.append("⌘") }
        parts.append(binding.glyph)
        return parts.joined(separator: " ")
    }
}

struct HotKeyField: View {
    @Binding var binding: HotKeyBinding?
    @StateObject private var recorder = HotKeyRecorderModel()

    var body: some View {
        HStack(spacing: 6) {
            Button(action: toggle) {
                Text(label)
                    .font(.system(.body, design: .monospaced))
                    .frame(minWidth: 90, alignment: .center)
                    .foregroundStyle(textStyle)
            }
            .buttonStyle(.bordered)

            if binding != nil && !recorder.isRecording {
                Button {
                    binding = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.borderless)
                .help("Clear shortcut")
            }
        }
        .onAppear {
            recorder.onCapture = { binding = $0 }
        }
        .onDisappear { recorder.stop() }
    }

    private var label: String {
        if recorder.isRecording { return "Press keys…" }
        guard let b = binding else { return "Click to set" }
        return HotKeyFormatter.string(for: b)
    }

    private var textStyle: HierarchicalShapeStyle {
        if recorder.isRecording { return .secondary }
        return binding == nil ? .secondary : .primary
    }

    private func toggle() {
        if recorder.isRecording {
            recorder.cancel()
        } else {
            recorder.start()
        }
    }
}
