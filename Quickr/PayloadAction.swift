import AppKit
import Foundation

struct PayloadAction {
    let label: String
    let run: (_ browserBundleID: String) -> Void

    struct Display {
        let icon: String
        let title: String?
        let subtitle: String
    }

    static func primary(for code: DetectedCode) -> PayloadAction? {
        switch code.kind {
        case .url(let url):
            return PayloadAction(label: "Open") { bid in openURL(url, browserBundleID: bid) }
        case .email(let url):
            return PayloadAction(label: "Compose") { _ in NSWorkspace.shared.open(url) }
        case .phone(let url):
            return PayloadAction(label: "Call") { _ in NSWorkspace.shared.open(url) }
        case .sms(let url):
            return PayloadAction(label: "Message") { _ in NSWorkspace.shared.open(url) }
        case .geo(let url):
            return PayloadAction(label: "Open in Maps") { _ in NSWorkspace.shared.open(url) }
        case .wifi(_, let password, _):
            guard let password else { return nil }
            return PayloadAction(label: "Copy Password") { _ in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(password, forType: .string)
            }
        case .vcard:
            return PayloadAction(label: "Add Contact") { _ in
                openTemporaryFile(contents: code.payload, ext: "vcf")
            }
        case .vevent:
            return PayloadAction(label: "Add to Calendar") { _ in
                openTemporaryFile(contents: code.payload, ext: "ics")
            }
        case .text:
            return nil
        }
    }

    /// What the "Copy" button copies. Wi-Fi copies just the password if present;
    /// everything else copies the raw payload so power-users can paste the original string.
    static func copyableText(for code: DetectedCode) -> String {
        if case .wifi(_, let password, _) = code.kind, let password { return password }
        return code.payload
    }

    static func display(for code: DetectedCode) -> Display {
        switch code.kind {
        case .url:
            return Display(icon: "link", title: nil, subtitle: code.payload)
        case .email:
            return Display(icon: "envelope", title: nil, subtitle: code.payload)
        case .phone:
            return Display(icon: "phone", title: nil, subtitle: code.payload)
        case .sms:
            return Display(icon: "message", title: nil, subtitle: code.payload)
        case .geo:
            return Display(icon: "mappin.and.ellipse", title: nil, subtitle: code.payload)
        case .wifi(let ssid, _, let security):
            let title = ssid.isEmpty ? "Wi-Fi network" : ssid
            let subtitle = security.map { "Security: \($0)" } ?? "Open network"
            return Display(icon: "wifi", title: title, subtitle: subtitle)
        case .vcard:
            return Display(icon: "person.crop.rectangle", title: "Contact", subtitle: vcardSummary(code.payload))
        case .vevent:
            return Display(icon: "calendar", title: "Calendar event", subtitle: veventSummary(code.payload))
        case .text:
            return Display(icon: "doc.text", title: nil, subtitle: code.payload)
        }
    }

    // MARK: - Helpers

    private static func openURL(_ url: URL, browserBundleID: String) {
        let workspace = NSWorkspace.shared
        if !browserBundleID.isEmpty,
           let appURL = workspace.urlForApplication(withBundleIdentifier: browserBundleID) {
            workspace.open([url], withApplicationAt: appURL,
                           configuration: NSWorkspace.OpenConfiguration())
        } else {
            workspace.open(url)
        }
    }

    private static func openTemporaryFile(contents: String, ext: String) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("quickr-\(UUID().uuidString)")
            .appendingPathExtension(ext)
        do {
            try contents.write(to: url, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(url)
        } catch {
            NSSound.beep()
        }
    }

    private static func vcardSummary(_ raw: String) -> String {
        firstLineValue(in: raw, keys: ["FN", "N"]) ?? "vCard"
    }

    private static func veventSummary(_ raw: String) -> String {
        firstLineValue(in: raw, keys: ["SUMMARY", "DESCRIPTION"]) ?? "Event"
    }

    private static func firstLineValue(in raw: String, keys: [String]) -> String? {
        for line in raw.split(whereSeparator: \.isNewline) {
            for key in keys {
                let upper = line.uppercased()
                if upper.hasPrefix("\(key):") {
                    return String(line.dropFirst(key.count + 1))
                }
                if upper.hasPrefix("\(key);") {
                    if let colon = line.firstIndex(of: ":") {
                        return String(line[line.index(after: colon)...])
                    }
                }
            }
        }
        return nil
    }
}
