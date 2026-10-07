import CryptoKit
import XCTest
@testable import NotesCore

final class NoteCryptoTests: XCTestCase {
    func testRoundTrip() throws {
        let c = NoteCrypto(key: NoteCrypto.generateKey())
        let blob = try c.seal("Secret ünïcode 🔐", context: "note-1")
        XCTAssertEqual(try c.open(blob, context: "note-1"), "Secret ünïcode 🔐")
    }

    func testCiphertextDoesNotContainPlaintext() throws {
        let c = NoteCrypto(key: NoteCrypto.generateKey())
        let blob = try c.seal("hunter2-hunter2-hunter2")
        XCTAssertNil(blob.range(of: Data("hunter2".utf8)))
    }

    func testSamePlaintextProducesDifferentCiphertext() throws {
        let c = NoteCrypto(key: NoteCrypto.generateKey())
        XCTAssertNotEqual(try c.seal("a"), try c.seal("a"), "nonce must be random")
    }

    func testWrongKeyFails() throws {
        let blob = try NoteCrypto(key: NoteCrypto.generateKey()).seal("x")
        XCTAssertThrowsError(try NoteCrypto(key: NoteCrypto.generateKey()).open(blob)) {
            XCTAssertEqual($0 as? NoteCryptoError, .corruptedCiphertext)
        }
    }

    func testWrongContextFails() throws {
        let c = NoteCrypto(key: NoteCrypto.generateKey())
        let blob = try c.seal("x", context: "note-1")
        XCTAssertThrowsError(try c.open(blob, context: "note-2"))
    }

    func testTamperingDetected() throws {
        let c = NoteCrypto(key: NoteCrypto.generateKey())
        var blob = try c.seal("hello")
        blob[blob.count - 1] ^= 0xFF
        XCTAssertThrowsError(try c.open(blob))
    }
}

final class NoteModelTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testOrderingPinnedFirstThenRecent() {
        let old = NoteSnapshot(title: "old", body: "", updatedAt: now.addingTimeInterval(-100))
        let new = NoteSnapshot(title: "new", body: "", updatedAt: now)
        let pinnedOld = NoteSnapshot(title: "pinned", body: "", updatedAt: now.addingTimeInterval(-999), isPinned: true)
        XCTAssertEqual(NoteOrdering.sorted([old, new, pinnedOld]).map(\.title), ["pinned", "new", "old"])
    }

    func testSearchMatchesAllTermsCaseAndDiacriticInsensitive() {
        let a = NoteSnapshot(title: "Café plans", body: "Meet on Friday")
        let b = NoteSnapshot(title: "Groceries", body: "milk, eggs")
        XCTAssertEqual(NoteSearch.filter([a, b], query: "cafe friday"), [a])
        XCTAssertEqual(NoteSearch.filter([a, b], query: "  ").count, 2)
        XCTAssertTrue(NoteSearch.filter([a, b], query: "zzz").isEmpty)
    }

    func testDisplayTitleNeverEmpty() {
        XCTAssertEqual(NoteSnapshot(title: "  \n", body: "").displayTitle, "Untitled note")
    }

    func testWordCountAndSpokenValue() {
        XCTAssertEqual(AccessibilityPhrases.rowValue(NoteSnapshot(title: "t", body: "one")), "1 word")
        XCTAssertEqual(AccessibilityPhrases.rowValue(NoteSnapshot(title: "t", body: "one two\nthree")), "3 words")
    }

    func testRowLabelIncludesPinnedAndRecency() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let n = NoteSnapshot(title: "Plan", body: "", updatedAt: now, isPinned: true)
        XCTAssertEqual(AccessibilityPhrases.rowLabel(n, now: now, calendar: cal), "Plan, Pinned, edited today")
        let older = NoteSnapshot(title: "Plan", body: "", updatedAt: now.addingTimeInterval(-3 * 86_400))
        XCTAssertEqual(AccessibilityPhrases.rowLabel(older, now: now, calendar: cal), "Plan, edited 3 days ago")
    }
}
