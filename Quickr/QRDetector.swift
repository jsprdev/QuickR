import CoreGraphics
import CoreImage
import Vision

enum PayloadKind {
    case url(URL)
    case wifi(ssid: String, password: String?, security: String?)
    case vcard
    case vevent
    case email(URL)
    case phone(URL)
    case sms(URL)
    case geo(URL)
    case text
}

struct DetectedCode: Identifiable {
    let id = UUID()
    let payload: String
    /// Normalized bounding box from Vision (0..1, origin bottom-left). nil for codes
    /// captured from a cropped drag region where the box maps trivially to the anchor.
    let boundingBox: CGRect?

    var url: URL? {
        guard let url = URL(string: payload), url.scheme != nil else { return nil }
        return url
    }

    var kind: PayloadKind {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.uppercased().hasPrefix("WIFI:") {
            let parsed = WifiPayload.parse(trimmed)
            return .wifi(ssid: parsed.ssid, password: parsed.password, security: parsed.security)
        }
        if trimmed.uppercased().hasPrefix("BEGIN:VCARD") { return .vcard }
        if trimmed.uppercased().hasPrefix("BEGIN:VEVENT") || trimmed.uppercased().hasPrefix("BEGIN:VCALENDAR") {
            return .vevent
        }

        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased() {
            switch scheme {
            case "http", "https": return .url(url)
            case "mailto":        return .email(url)
            case "tel", "facetime", "facetime-audio": return .phone(url)
            case "sms", "smsto":  return .sms(url)
            case "geo":           return .geo(url)
            default:              return .url(url)
            }
        }
        return .text
    }
}

enum QRDetector {
    static func detect(in image: CGImage) async -> [DetectedCode] {
        await withCheckedContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, _ in
                let observations = request.results as? [VNBarcodeObservation] ?? []
                let codes = observations.compactMap { obs -> DetectedCode? in
                    guard let payload = obs.payloadStringValue, !payload.isEmpty else { return nil }
                    return DetectedCode(payload: payload, boundingBox: obs.boundingBox)
                }
                continuation.resume(returning: codes)
            }
            request.symbologies = [.qr]

            do {
                try VNImageRequestHandler(cgImage: image).perform([request])
            } catch {
                continuation.resume(returning: [])
            }
        }
    }
}

/// Parser for the `WIFI:T:<auth>;S:<ssid>;P:<pass>;H:<hidden>;;` standard.
/// Handles backslash escaping of `;`, `,`, `:`, `\`, and `"`.
enum WifiPayload {
    struct Fields {
        let ssid: String
        let password: String?
        let security: String?
    }

    static func parse(_ raw: String) -> Fields {
        let body = String(raw.dropFirst("WIFI:".count))
        var fields: [String: String] = [:]
        var key = ""
        var value = ""
        var inKey = true
        var escape = false

        for char in body {
            if escape {
                value.append(char)
                escape = false
                continue
            }
            if char == "\\" {
                if inKey { key.append(char) } else { escape = true }
                continue
            }
            if inKey {
                if char == ":" { inKey = false } else { key.append(char) }
            } else {
                if char == ";" {
                    if !key.isEmpty { fields[key.uppercased()] = value }
                    key = ""; value = ""; inKey = true
                } else {
                    value.append(char)
                }
            }
        }
        if !key.isEmpty { fields[key.uppercased()] = value }

        return Fields(
            ssid: fields["S"] ?? "",
            password: (fields["P"]?.isEmpty == false) ? fields["P"] : nil,
            security: fields["T"]
        )
    }
}
