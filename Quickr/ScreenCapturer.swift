import AppKit
import ScreenCaptureKit

enum ScreenCapturer {
    /// Captures `rect` (in global AppKit coords) from the given display as a `CGImage`.
    /// All inputs are `Sendable` primitives so this function is safe to call across actor boundaries.
    static func capture(
        displayID: CGDirectDisplayID,
        screenFrame: CGRect,
        backingScale: CGFloat,
        rect: CGRect
    ) async -> CGImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
            guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
                return nil
            }

            // Convert global AppKit rect (bottom-left origin) to display-local CG rect (top-left origin).
            let localX = rect.origin.x - screenFrame.origin.x
            let localY = screenFrame.height - (rect.origin.y - screenFrame.origin.y) - rect.height
            let cropRect = CGRect(x: localX, y: localY, width: rect.width, height: rect.height)

            let filter = SCContentFilter(display: display, excludingWindows: [])
            let config = SCStreamConfiguration()
            config.sourceRect = cropRect
            config.width = Int(cropRect.width * backingScale)
            config.height = Int(cropRect.height * backingScale)
            config.scalesToFit = false
            config.showsCursor = false
            config.capturesAudio = false

            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        } catch {
            return nil
        }
    }
}
