# Quickr

A lightweight macOS menu bar app for fast QR code scanning from anywhere on screen.

Press `⌘⇧8`, drag a rectangle around any QR code visible on screen, and Quickr decodes it and offers to open the URL in your browser.

## How it works

```
[⌘⇧8 anywhere]  →  drag selection  →  capture region  →  decode QR  →  open / copy
```

- **Hotkey**: `⌘⇧8` (configurable as a future enhancement)
- **Selection**: macOS-native overlay matching the system screenshot UX
- **Decoding**: Apple's Vision framework (`VNDetectBarcodesRequest`)
- **Capture**: ScreenCaptureKit (`SCScreenshotManager`)
- **Browser**: system default by default; override per-app in Settings

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+ (to build)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Build & run

```sh
xcodegen generate
open Quickr.xcodeproj
# Press ⌘R in Xcode
```

On first scan, macOS will prompt for **Screen Recording** permission. Grant it in System Settings → Privacy & Security → Screen Recording, then relaunch.

## Project layout

```
quickr/
├── project.yml              XcodeGen project definition
├── Quickr/
│   ├── Info.plist
│   ├── QuickrApp.swift      @main, AppDelegate, menu bar, scan orchestrator
│   ├── HotKeyManager.swift  Carbon RegisterEventHotKey wrapper
│   ├── RegionSelector.swift Transparent overlay for drag-to-select
│   ├── ScreenCapturer.swift ScreenCaptureKit region capture
│   ├── QRDetector.swift     Vision QR decoding
│   ├── ResultWindow.swift   Floating result panel + open/copy
│   └── Preferences.swift    SwiftUI settings (browser picker)
└── README.md
```

## Notes

- **Unsandboxed by design**: ScreenCaptureKit's region capture is awkward under the App Sandbox. Same call as Rectangle, CleanShot, and other screen tools. Hardened Runtime is enabled.
- **No analytics, no login item, no auto-update**. Single-user, single-purpose.
- **Non-URL payloads** (Wi-Fi credentials, vCard, plain text) are detected and offered for copy.
# QuickR
# QuickR
