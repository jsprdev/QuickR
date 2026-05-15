import ServiceManagement
import SwiftUI

/// Thin wrapper around `SMAppService.mainApp` so the Settings UI can toggle
/// Quickr's auto-launch behavior at login.
@MainActor
final class LaunchAtLogin: ObservableObject {
    static let shared = LaunchAtLogin()

    @Published private(set) var isEnabled: Bool = false

    private init() {
        refresh()
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Most common cause: the app isn't in /Applications yet, or the user
            // declined the approval prompt in System Settings → Login Items.
            NSLog("Launch at Login error: \(error.localizedDescription)")
        }
        refresh()
    }
}
