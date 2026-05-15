import AppKit
import SwiftUI

// MARK: - Window controller

@MainActor
final class PreferencesWindowController {
    private var window: NSWindow?

    func show() {
        NSApp.activate()
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }

        let host = NSHostingController(rootView: PreferencesView())
        host.sizingOptions = .preferredContentSize
        host.view.layoutSubtreeIfNeeded()
        let size = host.view.fittingSize == .zero
            ? NSSize(width: 520, height: 640)
            : host.view.fittingSize

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = ""
        window.contentViewController = host
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
    }
}

// MARK: - Root view

struct PreferencesView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                hero
                ShortcutsCard()
                BrowserCard()
                AppearanceCard()
                HistoryCard()
                AboutCard()
                CreditFooter()
                    .padding(.top, 4)
            }
            .padding(.horizontal, 36)
            .padding(.top, 32)
            .padding(.bottom, 24)
        }
        .frame(width: 520, height: 640)
        .background(WindowBackground())
    }

    private var hero: some View {
        VStack(spacing: 6) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 42, weight: .regular))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
                .padding(.bottom, 2)

            Text("Settings")
                .font(.system(size: 24, weight: .semibold, design: .rounded))

            Text("Tune how Quickr scans, where links open, and what your bubble looks like.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Sections

private struct ShortcutsCard: View {
    @ObservedObject private var hotkeys = HotKeyStore.shared

    private var dragBinding: Binding<HotKeyBinding?> {
        Binding(get: { hotkeys.drag }, set: { hotkeys.set($0, for: .drag) })
    }
    private var smartBinding: Binding<HotKeyBinding?> {
        Binding(get: { hotkeys.smart }, set: { hotkeys.set($0, for: .smart) })
    }

    var body: some View {
        SettingsCard(
            "Shortcuts",
            footer: "Drag mode lets you select a region around a QR. Smart mode auto-finds every QR visible on screen. Leave either blank to disable it."
        ) {
            VStack(spacing: 0) {
                ShortcutRow(
                    icon: "rectangle.dashed",
                    title: "Drag to scan",
                    binding: dragBinding
                )
                Divider().padding(.vertical, 12)
                ShortcutRow(
                    icon: "sparkles.rectangle.stack",
                    title: "Smart scan",
                    binding: smartBinding
                )
            }
        }
    }
}

private struct ShortcutRow: View {
    let icon: String
    let title: String
    @Binding var binding: HotKeyBinding?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 24)
            Text(title)
                .font(.callout)
            Spacer()
            HotKeyField(binding: $binding)
        }
    }
}

private struct BrowserCard: View {
    @AppStorage("browserBundleID") private var browserBundleID: String = ""
    @State private var browsers: [BrowserInfo] = []

    var body: some View {
        SettingsCard("Browser") {
            HStack(spacing: 12) {
                Image(systemName: "safari")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 24)
                Text("Open links in")
                    .font(.callout)
                Spacer()
                Picker("", selection: $browserBundleID) {
                    Text("System Default").tag("")
                    Divider()
                    ForEach(browsers) { browser in
                        Text(browser.name).tag(browser.bundleID)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 200)
            }
        }
        .onAppear { browsers = BrowserInfo.installed() }
    }
}

private struct AppearanceCard: View {
    @AppStorage("bubbleStyle") private var styleRaw: String = BubbleStyle.liquidGlass.rawValue
    @AppStorage("bubbleColor") private var colorHex: String = "#1E1E1EE6"

    private var style: BubbleStyle {
        get { BubbleStyle(rawValue: styleRaw) ?? .liquidGlass }
    }
    private var styleBinding: Binding<BubbleStyle> {
        Binding(
            get: { BubbleStyle(rawValue: styleRaw) ?? .liquidGlass },
            set: { styleRaw = $0.rawValue }
        )
    }
    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: colorHex) },
            set: { colorHex = $0.hexString }
        )
    }

    var body: some View {
        SettingsCard("Result Bubble", footer: "Choose how the result popup looks when Quickr finds a QR.") {
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "paintbrush")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.tint)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 24)
                    Text("Style")
                        .font(.callout)
                    Spacer()
                    Picker("", selection: styleBinding) {
                        ForEach(BubbleStyle.allCases) { s in
                            Text(s.label).tag(s)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: 200)
                }

                if style == .solid {
                    Divider()
                    HStack(spacing: 12) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.tint)
                            .symbolRenderingMode(.hierarchical)
                            .frame(width: 24)
                        Text("Color")
                            .font(.callout)
                        Spacer()
                        ColorPicker("", selection: colorBinding, supportsOpacity: true)
                            .labelsHidden()
                    }
                }
            }
        }
    }
}

private struct HistoryCard: View {
    @ObservedObject private var store = HistoryStore.shared
    @AppStorage("browserBundleID") private var browserBundleID: String = ""

    var body: some View {
        SettingsCard("History", footer: "Your last 50 scans live on this Mac. Nothing is uploaded anywhere.") {
            if store.entries.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 22))
                        .foregroundStyle(.tertiary)
                    Text("No scans yet")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(store.entries) { entry in
                                HistoryRow(entry: entry, browserBundleID: browserBundleID) {
                                    store.remove(entry)
                                }
                                if entry.id != store.entries.last?.id {
                                    Divider().padding(.leading, 36)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 200)

                    Divider().padding(.top, 4)

                    HStack {
                        Text("\(store.entries.count) of 50")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Clear All", role: .destructive) { store.clear() }
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                    }
                    .padding(.top, 10)
                }
            }
        }
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry
    let browserBundleID: String
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: entry.isURL ? "link" : "doc.text")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .frame(width: 22, alignment: .center)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.payload)
                    .font(.system(.callout, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                Text(entry.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if let url = entry.url {
                Button {
                    open(url)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.borderless)
                .help("Open")
            }
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.payload, forType: .string)
            } label: {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.borderless)
            .help("Copy")

            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.borderless)
            .help("Remove")
        }
        .padding(.vertical, 6)
    }

    private func open(_ url: URL) {
        let workspace = NSWorkspace.shared
        if !browserBundleID.isEmpty,
           let appURL = workspace.urlForApplication(withBundleIdentifier: browserBundleID) {
            workspace.open([url], withApplicationAt: appURL,
                           configuration: NSWorkspace.OpenConfiguration())
        } else {
            workspace.open(url)
        }
    }
}

private struct AboutCard: View {
    var body: some View {
        SettingsCard("About") {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.tint)
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 24)
                Text("Welcome screen")
                    .font(.callout)
                Spacer()
                Button("Show Again") {
                    WelcomeWindowController.shared.show()
                }
            }
        }
    }
}

// MARK: - Browser enumeration

struct BrowserInfo: Identifiable, Hashable {
    let bundleID: String
    let name: String
    var id: String { bundleID }

    static func installed() -> [BrowserInfo] {
        guard let httpURL = URL(string: "https://example.com") else { return [] }
        let urls = NSWorkspace.shared.urlsForApplications(toOpen: httpURL)
        var seen = Set<String>()
        return urls.compactMap { url -> BrowserInfo? in
            guard let bundle = Bundle(url: url),
                  let id = bundle.bundleIdentifier,
                  seen.insert(id).inserted else { return nil }
            let name = FileManager.default.displayName(atPath: url.path)
                .replacingOccurrences(of: ".app", with: "")
            return BrowserInfo(bundleID: id, name: name)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
