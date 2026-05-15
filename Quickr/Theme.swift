import AppKit
import Carbon.HIToolbox
import SwiftUI

// MARK: - Shared window chrome

/// Subtle gradient backdrop used by all custom-chrome windows in Quickr.
struct WindowBackground: View {
    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor)
            LinearGradient(
                colors: [Color.accentColor.opacity(0.08), .clear],
                startPoint: .top,
                endPoint: .center
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Keycap visuals (shared with WelcomeWindow)

struct KeycapRow: View {
    let binding: HotKeyBinding

    var body: some View {
        HStack(spacing: 6) {
            ForEach(modifierGlyphs, id: \.self) { glyph in
                Keycap(label: glyph, isModifier: true)
            }
            Keycap(label: binding.glyph, isModifier: false)
        }
    }

    private var modifierGlyphs: [String] {
        var out: [String] = []
        let m = binding.modifiers
        if m & UInt32(controlKey) != 0 { out.append("⌃") }
        if m & UInt32(optionKey)  != 0 { out.append("⌥") }
        if m & UInt32(shiftKey)   != 0 { out.append("⇧") }
        if m & UInt32(cmdKey)     != 0 { out.append("⌘") }
        return out
    }
}

struct Keycap: View {
    let label: String
    let isModifier: Bool

    var body: some View {
        Text(label)
            .font(.system(size: isModifier ? 18 : 20,
                          weight: .semibold,
                          design: .rounded))
            .frame(minWidth: isModifier ? 36 : 40, minHeight: 40)
            .padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.08), radius: 1, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
    }
}

// MARK: - Credit footer (shared with WelcomeWindow and Settings)

struct CreditFooter: View {
    var body: some View {
        HStack(spacing: 8) {
            Text("Made by [jsprdev](https://www.linkedin.com/in/jsprdev)")
            Text("·").foregroundStyle(.tertiary)
            Link(destination: URL(string: "https://github.com/jsprdev/QuickR")!) {
                Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    .labelStyle(.titleAndIcon)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .tint(.secondary)
    }
}

// MARK: - Card section

/// Vertical card section: optional uppercase header, rounded translucent body,
/// optional caption footer. Matches the Welcome window's `shortcutHero` look.
struct SettingsCard<Content: View>: View {
    let title: String?
    let footer: String?
    @ViewBuilder var content: Content

    init(_ title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.footnote)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.leading, 4)
            }
            content
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.quaternary.opacity(0.5))
                )
            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Bubble appearance

enum BubbleStyle: String, CaseIterable, Identifiable {
    case liquidGlass
    case material
    case solid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .liquidGlass: return "Liquid Glass"
        case .material:    return "Material"
        case .solid:       return "Solid Color"
        }
    }
}

extension Color {
    /// "#RRGGBBAA" hex string round-trip, via NSColor (the only `Color` form that
    /// reliably exposes RGBA components on macOS).
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Foundation.Scanner(string: cleaned).scanHexInt64(&v)
        let r, g, b, a: Double
        switch cleaned.count {
        case 8:
            r = Double((v >> 24) & 0xFF) / 255
            g = Double((v >> 16) & 0xFF) / 255
            b = Double((v >> 8)  & 0xFF) / 255
            a = Double(v        & 0xFF) / 255
        case 6:
            r = Double((v >> 16) & 0xFF) / 255
            g = Double((v >> 8)  & 0xFF) / 255
            b = Double(v         & 0xFF) / 255
            a = 1
        default:
            r = 1; g = 1; b = 1; a = 1
        }
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    var hexString: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .white
        let r = Int(round(ns.redComponent   * 255))
        let g = Int(round(ns.greenComponent * 255))
        let b = Int(round(ns.blueComponent  * 255))
        let a = Int(round(ns.alphaComponent * 255))
        return String(format: "#%02X%02X%02X%02X", r, g, b, a)
    }
}

