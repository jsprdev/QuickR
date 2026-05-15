<h1 align="center">Quickr</h1>

<h6 align="center">
  Click, drag, and scan. It's even simpler than it sounds.
</h6>

<p align="center">
  a lightweight, ultra-fast, native QR code scanner for macOS
</p>


<p align="center">
  <kbd>⌘</kbd> <kbd>⇧</kbd> <kbd>8</kbd>
</p>

---

## Quick start

1. Press **⌘ ⇧ 8** (Cmd + Shift + 8) anywhere on your Mac.
2. Drag a rectangle around the QR code.
3. Open the link, copy the text, or take a smart action.

That's it.

---
<br></br>
<br></br>

## Quality of Life

- **One shortcut, anywhere** — default **⌘ ⇧ 8**, change it in Settings.
- **Smart actions** — opens links, copies Wi-Fi passwords, adds contacts, saves calendar events.
- **Smart Scan mode** — bind a second hotkey to auto-find every QR on screen with no dragging.
- **Lives in the menu bar** — out of the way until you need it.
- **Private by design** — no analytics, no login, no cloud. Everything stays on your Mac.

---

## Advanced

### Smart Scan
Open **Settings → General → Smart scan** and record any shortcut. Press it from anywhere — Quickr captures the screen under your cursor, finds every QR, and shows you the result. Leave it blank to disable.

### Choose a browser
URLs open in your system default by default. Override under **Settings → General → Open links in**.

### Result bubble appearance
Three styles: **Liquid Glass**, **Material**, **Solid Color**. Pick one under **Settings → Appearance**. Solid lets you set any hex color including alpha.

### History
Your last 50 scans are kept locally. Open, copy, or clear them under **Settings → History**.

### Supported payload types
| Payload | Primary action |
|---|---|
| URL (`http`, `https`) | Open in browser |
| Email (`mailto:`) | Compose |
| Phone (`tel:`) | Call |
| SMS (`sms:`) | Message |
| Location (`geo:`) | Open in Maps |
| Wi-Fi (`WIFI:…`) | Copy password |
| Contact (`BEGIN:VCARD`) | Add to Contacts |
| Calendar (`BEGIN:VEVENT`) | Add to Calendar |
| Plain text | Copy |

---

## Requirements

- macOS 14 (Sonoma) or later
- **Screen Recording** permission — granted on first scan (or from the welcome window)

## Build from source

```sh
brew install xcodegen
xcodegen generate
open Quickr.xcodeproj
```

Press **⌘R** in Xcode.

---

<p align="center">
  <sub>No analytics. No login. No cloud.</sub>
</p>
