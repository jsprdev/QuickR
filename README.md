
<p align="center">
  <img width="150" height="150" alt="Logo for Quickr" src="https://github.com/user-attachments/assets/563655ac-dc97-4ddf-82f0-08b3eb7f34e3" />  
</p>

<h1 align="center">Quickr</h1>


<p align="center">
  a lightweight, ultra-fast, native QR code scanner for macOS
</p>

<h6 align="center">
  Click, drag, and scan. It's even simpler than it sounds.
</h6>

<p align="center">
  <kbd>⌘</kbd> <kbd>⇧</kbd> <kbd>8</kbd>
</p>

<p align="center">
  <a href="https://github.com/jsprdev/QuickR/releases/latest/download/Quickr.dmg">
    <img src="https://img.shields.io/github/v/release/jsprdev/QuickR?label=Download%20for%20macOS&style=for-the-badge&color=111&labelColor=111&logo=apple&logoColor=white" alt="Download Quickr">
  </a>
  <br />
  <sub>macOS 14 (Sonoma) or later · Apple Silicon &amp; Intel</sub>
</p>

---

## Quick start

1. Press **⌘ ⇧ 8** (Cmd + Shift + 8) anywhere on your Mac.
2. Drag-click a region around the QR code. Just like taking a screenshot.
3. Open the link, copy the text, or take a smart action.

That's it.

---

<img width="400" height="336" alt="quickr demo" src="https://github.com/user-attachments/assets/f159a7bc-280c-446e-8b65-3ceffdb797c0" /> <img width="400" height="336" alt="quickr multi qr" src="https://github.com/user-attachments/assets/de086b16-d134-4143-ad90-b73a69be5d82" />

## Features
<table>
<tr>
<td width="50%" valign="top">

### One shortcut, anywhere

Default <kbd>⌘</kbd> <kbd>⇧</kbd> <kbd>8</kbd>. Change it in Settings.

</td>
<td width="50%" valign="top">

### Smart actions

Opens links, copies Wi-Fi passwords, adds contacts, saves calendar events.
<br></br>

</td>
</tr>
<tr>
<td valign="top">

### Smart Scan mode

Bind a second hotkey to auto-find every QR on screen with no dragging.
<br></br>

</td>
<td valign="top">

### Lives in the menu bar

Out of the way until you need it.

</td>
</tr>
<tr>
<td colspan="2" valign="top">

### History
Your last 50 scans are kept locally. Open, copy, or clear them under **Settings → History**.
<br></br>
</td>
</tr>
</table>

---

## Advanced

### Choose a browser
URLs open in your system default by default. Override under **Settings → General → Open links in**.

### Result bubble appearance
Three styles: **Liquid Glass**, **Material**, **Solid Color**. Pick one under **Settings → Appearance**. Solid lets you set any hex color including alpha.


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
  <sub>Fully open-source! Everything runs on your Mac.</sub>
</p>
