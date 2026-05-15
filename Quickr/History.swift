import AppKit
import SwiftUI

struct HistoryEntry: Codable, Identifiable, Hashable {
    let id: UUID
    let payload: String
    let timestamp: Date
    let isURL: Bool

    init(payload: String, isURL: Bool, timestamp: Date = .now) {
        self.id = UUID()
        self.payload = payload
        self.isURL = isURL
        self.timestamp = timestamp
    }

    var url: URL? {
        guard isURL, let u = URL(string: payload), u.scheme != nil else { return nil }
        return u
    }
}

@MainActor
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    private static let key = "scanHistory"
    private static let cap = 50

    @Published private(set) var entries: [HistoryEntry]

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode([HistoryEntry].self, from: data) {
            self.entries = decoded
        } else {
            self.entries = []
        }
    }

    func record(payload: String, isURL: Bool) {
        // Promote duplicates to the top instead of stacking copies.
        entries.removeAll { $0.payload == payload }
        entries.insert(HistoryEntry(payload: payload, isURL: isURL), at: 0)
        if entries.count > Self.cap {
            entries.removeLast(entries.count - Self.cap)
        }
        persist()
    }

    func remove(_ entry: HistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func clear() {
        entries.removeAll()
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }
}

// History UI lives in Preferences.swift as the `HistoryCard` section.
