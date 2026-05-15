import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI

@main
struct QuickrApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // App protocol requires a Scene. `Settings { … }` is the only scene type
        // that doesn't auto-open a window at launch and doesn't add a visible
        // menu bar. macOS still binds ⌘, to it, so route that to PreferencesView
        // (the same view the custom window controller uses) — this way ⌘, is a
        // harmless second path to the same UI instead of opening a blank window.
        Settings { PreferencesView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let hotKey = HotKeyManager()
    private let scanner = Scanner()
    private lazy var preferences = PreferencesWindowController()
    private let welcome = WelcomeWindowController.shared

    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let icon = NSImage(systemSymbolName: "qrcode.viewfinder", accessibilityDescription: "Quickr")
            icon?.isTemplate = true
            button.image = icon
        }
        rebuildMenu()

        let store = HotKeyStore.shared
        registerHotKeys()

        // React to binding changes (user edited in Settings).
        Publishers.CombineLatest(store.$drag, store.$smart)
            .dropFirst()
            .sink { [weak self] _, _ in
                self?.registerHotKeys()
                self?.rebuildMenu()
            }
            .store(in: &cancellables)

        // Suspend the global hotkeys while a recorder is capturing keys.
        store.$isRecording
            .dropFirst()
            .sink { [weak self] recording in
                if recording {
                    self?.hotKey.unregisterAll()
                } else {
                    self?.registerHotKeys()
                }
            }
            .store(in: &cancellables)

        // Defer one runloop tick so the menu bar item is on screen before the
        // welcome window appears — gives the user a visual anchor for "where
        // does the app live?".
        DispatchQueue.main.async { [weak self] in
            self?.welcome.showIfFirstLaunch()
        }
    }

    private func registerHotKeys() {
        hotKey.unregisterAll()
        if let drag = HotKeyStore.shared.drag {
            hotKey.register(slot: .drag, binding: drag) { [weak self] in self?.scanDrag() }
        }
        if let smart = HotKeyStore.shared.smart {
            hotKey.register(slot: .smart, binding: smart) { [weak self] in self?.scanSmart() }
        }
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        let drag = NSMenuItem(title: "Drag to Scan", action: #selector(scanDrag), keyEquivalent: "")
        drag.target = self
        applyKeyEquivalent(to: drag, binding: HotKeyStore.shared.drag)
        menu.addItem(drag)

        let smart = NSMenuItem(title: "Smart Scan", action: #selector(scanSmart), keyEquivalent: "")
        smart.target = self
        applyKeyEquivalent(to: smart, binding: HotKeyStore.shared.smart)
        menu.addItem(smart)

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(title: "Settings…", action: #selector(openPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)

        let welcomeItem = NSMenuItem(title: "Welcome to Quickr…", action: #selector(openWelcome), keyEquivalent: "")
        welcomeItem.target = self
        menu.addItem(welcomeItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit Quickr", action: #selector(NSApp.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    /// Reflect the user's current hotkey on the menu item — but only as a visual hint.
    /// The actual triggering is done by HotKeyManager (Carbon), not by NSMenu.
    private func applyKeyEquivalent(to item: NSMenuItem, binding: HotKeyBinding?) {
        guard let binding else {
            item.keyEquivalent = ""
            item.keyEquivalentModifierMask = []
            return
        }
        item.keyEquivalent = binding.glyph.lowercased()
        var mask: NSEvent.ModifierFlags = []
        if binding.modifiers & UInt32(cmdKey) != 0 { mask.insert(.command) }
        if binding.modifiers & UInt32(shiftKey) != 0 { mask.insert(.shift) }
        if binding.modifiers & UInt32(optionKey) != 0 { mask.insert(.option) }
        if binding.modifiers & UInt32(controlKey) != 0 { mask.insert(.control) }
        item.keyEquivalentModifierMask = mask
    }

    @objc private func scanDrag() { scanner.startDrag() }
    @objc private func scanSmart() { scanner.startSmart() }

    @objc private func openPreferences() {
        NSApp.activate()
        preferences.show()
    }

    @objc private func openWelcome() {
        NSApp.activate()
        welcome.show()
    }
}

@MainActor
final class Scanner {
    private var selector: RegionSelector?
    private var resultWindow: ResultWindow?
    private var isScanning = false

    // MARK: - Drag mode

    func startDrag() {
        guard !isScanning else { return }
        isScanning = true

        resultWindow?.close()
        resultWindow = nil

        NSApp.activate()

        let selector = RegionSelector()
        self.selector = selector
        selector.onComplete = { [weak self] result in
            guard let self else { return }
            self.selector = nil
            guard let result else { self.isScanning = false; return }
            let displayID = (result.screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
            let frame = result.screen.frame
            let visibleFrame = result.screen.visibleFrame
            let scale = result.screen.backingScaleFactor
            guard let displayID else { self.isScanning = false; return }
            Task {
                await self.processDrag(displayID: displayID, screenFrame: frame, visibleFrame: visibleFrame, backingScale: scale, rect: result.rect)
            }
        }
        selector.present()
    }

    private func processDrag(displayID: CGDirectDisplayID, screenFrame: CGRect, visibleFrame: CGRect, backingScale: CGFloat, rect: CGRect) async {
        defer { isScanning = false }

        // Give the WindowServer a frame to remove the dismissed overlay windows
        // before capturing — otherwise the dim layer can show up in the screenshot.
        try? await Task.sleep(nanoseconds: 100_000_000)

        guard let image = await ScreenCapturer.capture(
            displayID: displayID,
            screenFrame: screenFrame,
            backingScale: backingScale,
            rect: rect
        ) else {
            NSSound.beep()
            return
        }

        let codes = await QRDetector.detect(in: image)
        guard !codes.isEmpty else {
            NSSound.beep()
            return
        }

        record(codes)
        showResult(codes: codes, anchor: rect, visibleFrame: visibleFrame)
    }

    // MARK: - Smart mode

    func startSmart() {
        guard !isScanning else { return }
        isScanning = true

        resultWindow?.close()
        resultWindow = nil

        // Use the screen containing the mouse cursor so smart mode targets the
        // display the user is actually looking at on multi-monitor setups.
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) })
            ?? NSScreen.main
            ?? NSScreen.screens.first
        guard let screen,
              let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        else {
            isScanning = false
            return
        }

        let frame = screen.frame
        let visibleFrame = screen.visibleFrame
        let scale = screen.backingScaleFactor

        Task {
            await self.processSmart(displayID: displayID, screenFrame: frame, visibleFrame: visibleFrame, scale: scale)
        }
    }

    private func processSmart(displayID: CGDirectDisplayID, screenFrame: CGRect, visibleFrame: CGRect, scale: CGFloat) async {
        defer { isScanning = false }

        guard let image = await ScreenCapturer.capture(
            displayID: displayID,
            screenFrame: screenFrame,
            backingScale: scale,
            rect: screenFrame
        ) else {
            NSSound.beep()
            return
        }

        let codes = await QRDetector.detect(in: image)
        guard !codes.isEmpty else {
            NSSound.beep()
            return
        }

        record(codes)

        // Vision boundingBox is normalized, origin bottom-left — same convention as
        // AppKit, so we can lift it straight into the screen's coordinate space.
        let anchor: CGRect
        if let bb = codes.first?.boundingBox {
            anchor = CGRect(
                x: screenFrame.minX + bb.minX * screenFrame.width,
                y: screenFrame.minY + bb.minY * screenFrame.height,
                width: bb.width * screenFrame.width,
                height: bb.height * screenFrame.height
            )
        } else {
            anchor = CGRect(x: visibleFrame.midX, y: visibleFrame.midY, width: 1, height: 1)
        }

        showResult(codes: codes, anchor: anchor, visibleFrame: visibleFrame)
    }

    // MARK: - Shared

    private func record(_ codes: [DetectedCode]) {
        for code in codes {
            HistoryStore.shared.record(payload: code.payload, isURL: code.url != nil)
        }
    }

    private func showResult(codes: [DetectedCode], anchor: CGRect, visibleFrame: CGRect) {
        let window = ResultWindow(codes: codes, near: anchor, visibleFrame: visibleFrame)
        resultWindow = window
        window.onClose = { [weak self] in self?.resultWindow = nil }
        window.show()
    }
}
