import Foundation

/// Decrypted, UI-facing value type for a note.
public struct NoteSnapshot: Identifiable, Equatable, Hashable {
    public var id: UUID
    public var title: String
    public var body: String
    public var updatedAt: Date
    public var isPinned: Bool

    public init(id: UUID = UUID(), title: String, body: String, updatedAt: Date = Date(), isPinned: Bool = false) {
        self.id = id
        self.title = title
        self.body = body
        self.updatedAt = updatedAt
        self.isPinned = isPinned
    }

    /// Title shown in lists; never empty so VoiceOver always has something to read.
    public var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled note" : trimmed
    }

    public var wordCount: Int {
        body.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }
}

public enum NoteOrdering {
    /// Pinned notes first, then most recently edited.
    public static func sorted(_ notes: [NoteSnapshot]) -> [NoteSnapshot] {
        notes.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }
}

public enum NoteSearch {
    /// Search runs on *decrypted* snapshots in memory (ciphertext can't be queried),
    /// case- and diacritic-insensitive; every whitespace-separated term must match.
    public static func filter(_ notes: [NoteSnapshot], query: String) -> [NoteSnapshot] {
        let terms = query.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !terms.isEmpty else { return notes }
        return notes.filter { note in
            terms.allSatisfy { term in
                note.title.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil
                    || note.body.range(of: term, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
        }
    }
}

/// Phrases tuned for VoiceOver: short, ordered most-important-first, no symbols.
public enum AccessibilityPhrases {
    public static func rowLabel(_ note: NoteSnapshot, now: Date = Date(), calendar: Calendar = .current) -> String {
        var parts = [note.displayTitle]
        if note.isPinned { parts.append("Pinned") }
        parts.append(relative(note.updatedAt, now: now, calendar: calendar))
        return parts.joined(separator: ", ")
    }

    public static func rowValue(_ note: NoteSnapshot) -> String {
        let n = note.wordCount
        return n == 1 ? "1 word" : "\(n) words"
    }

    static func relative(_ date: Date, now: Date, calendar: Calendar) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return "edited today" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return "edited yesterday" }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        return days > 0 ? "edited \(days) days ago" : "edited in the future"
    }
}
