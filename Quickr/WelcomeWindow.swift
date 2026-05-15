import AppKit
import Carbon.HIToolbox
import CoreGraphics
import SwiftUI

// MARK: - Content (tweak copy / features here)

private enum WelcomeContent {
    static let title = "Welcome to Quickr"
    static let tagline = "Decode any QR code visible on your screen — instantly."
    static let primaryCTA = "Get Started"
    static let shortcutCaption = "Press anywhere, drag a rectangle, done."

    static let features: [WelcomeFeature] = [
        WelcomeFeature(
            icon: "sparkles",
            title: "Smart actions",
            detail: "Open links, copy Wi-Fi passwords, add contacts, save calendar events."
        ),
        WelcomeFeature(
            icon: "menubar.dock.rectangle",
            title: "Lives in the menu bar",
            detail: "Out of the way until you need it. One shortcut from anywhere."
        ),
        WelcomeFeature(
            icon: "lock.shield",
            title: "Private by design",
            detail: "Everything happens on your Mac. No analytics, no login, no cloud."
        )
    ]
}

struct WelcomeFeature: Identifiable {
    let id = UUID()
    let icon: String
    let title: String
    let detail: String
}

// MARK: - Window controller

@MainActor
final class WelcomeWindowController {
    static let shared = WelcomeWindowController()
    static let hasSeenKey = "hasSeenWelcome"

    private var window: NSWindow?

    private init() {}

    func showIfFirstLaunch() {
        guard !UserDefaults.standard.bool(forKey: Self.hasSeenKey) else { return }
        show()
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        let view = WelcomeView(onDismiss: { [weak self] in self?.dismiss() })
        let host = NSHostingController(rootView: view)
        host.sizingOptions = .preferredContentSize

        let window = NSWindow(contentViewController: host)
        window.title = ""
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        self.window = window
    }

    private func dismiss() {
        UserDefaults.standard.set(true, forKey: Self.hasSeenKey)
        window?.close()
        window = nil
    }
}

// MARK: - Root view

private struct WelcomeView: View {
    let onDismiss: () -> Void

    @ObservedObject private var hotkeys = HotKeyStore.shared
    @State private var permissionGranted: Bool = CGPreflightScreenCaptureAccess()

    var body: some View {
        VStack(spacing: 22) {
            hero
            shortcutHero
            featuresList
            if !permissionGranted { permissionCard }
            Spacer(minLength: 0)
            ctaButton
            CreditFooter()
                .padding(.top, 4)
        }
        .padding(.horizontal, 36)
        .padding(.top, 40)
        .padding(.bottom, 20)
        .frame(width: 460)
        .background(WindowBackground())
        .onAppear { recheckPermission() }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            recheckPermission()
        }
    }

    // MARK: Sections

    private var hero: some View {
        VStack(spacing: 10) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 56, weight: .regular))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
                .padding(.bottom, 4)

            Text(WelcomeContent.title)
                .font(.system(size: 26, weight: .semibold, design: .rounded))

            Text(WelcomeContent.tagline)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var shortcutHero: some View {
        if let binding = hotkeys.drag {
            VStack(spacing: 8) {
                KeycapRow(binding: binding)
                Text(WelcomeContent.shortcutCaption)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.quaternary.opacity(0.5))
            )
        } else {
            VStack(spacing: 6) {
                Text("No shortcut set")
                    .font(.callout)
                    .fontWeight(.medium)
                Text("Open Settings to choose one.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.quaternary.opacity(0.5))
            )
        }
    }

    private var featuresList: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(WelcomeContent.features) { feature in
                FeatureRow(feature: feature)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var permissionCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(.orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text("Screen Recording required")
                    .font(.callout)
                    .fontWeight(.medium)
                Text("macOS needs permission to capture the area you select.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button("Open Settings") {
                openPermissionSettings()
            }
            .controlSize(.small)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.25), lineWidth: 0.5)
        )
    }

    private var ctaButton: some View {
        Button(action: onDismiss) {
            Text(WelcomeContent.primaryCTA)
                .frame(minWidth: 140)
        }
        .controlSize(.large)
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
    }

    // MARK: Side effects

    private func recheckPermission() {
        permissionGranted = CGPreflightScreenCaptureAccess()
    }

    private func openPermissionSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
        // Side-effect: trigger the system's own permission prompt path if it's
        // never been requested before. Harmless if already granted/denied.
        CGRequestScreenCaptureAccess()
    }
}

// MARK: - Subviews

private struct FeatureRow: View {
    let feature: WelcomeFeature

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: feature.icon)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.tint)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(feature.title)
                    .font(.callout)
                    .fontWeight(.medium)
                Text(feature.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// KeycapRow, Keycap, and WindowBackground are shared between the Welcome
// and Settings windows — see Theme.swift.
