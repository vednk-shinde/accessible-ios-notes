# Accessible Notes — end-to-end encrypted, CloudKit-synced SwiftUI notes app

A native iOS notes app built accessibility-first. Note text is **encrypted on device** (AES-256-GCM via CryptoKit)
before it is stored in Core Data, and Core Data mirrors the ciphertext to the user's private **CloudKit** database,
so Apple's servers and any sync bugs only ever see opaque bytes. The key lives in the **iCloud Keychain**, so
all of a user's devices can decrypt.

> **Status (honest):** this repo was authored without access to a Mac, so it has **not yet been compiled or run
> on a device**. CI (`.github/workflows/ci.yml`) builds it and runs the unit and UI/accessibility tests on a macOS runner —
> check the Actions tab. Not on TestFlight/App Store yet; see "Shipping" below.

## Architecture

```
SwiftUI views ── NoteStore (decrypt/encrypt, ObservableObject) ── Core Data (ciphertext only)
                      │                                              │ NSPersistentCloudKitContainer
                 NotesCore (Swift package)                      CloudKit private DB
                 • NoteCrypto  AES-GCM, id bound as AAD
                 • KeychainKeyStore  iCloud Keychain key
                 • NoteSearch / NoteOrdering / AccessibilityPhrases
```

* **`NotesCore`** is UI-free so it is unit-tested with plain `swift test`.
* **Schema is code-defined** (`PersistenceController`), CloudKit-compatible (all optional/defaulted, no uniqueness constraints).
* The note id is authenticated data, so ciphertext can't be copied from one note to another undetected.
* Search runs on decrypted in-memory snapshots (ciphertext isn't queryable).

## Accessibility (a design goal, not a checklist)

| Feature | Where |
|---|---|
| VoiceOver labels/values/hints per row ("Plan, Pinned, edited today — 12 words") | `AccessibilityPhrases`, `NoteRow` |
| **Custom rotor** to jump between pinned notes | `NoteListView` |
| Swipe actions duplicated as **named accessibility actions** (usable with VoiceOver, Switch Control, AssistiveTouch) | `NoteListView` |
| **Dynamic Type** up to AX5: semantic fonts, `@ScaledMetric` icons | all views |
| Pinned state shown by icon + text + spoken label, never colour alone | `NoteRow` |
| Reduce Motion respected; VoiceOver announcements on state change | `NoteEditorView` |
| Automated **accessibility audits** (`performAccessibilityAudit`) at default and AX XXXL text | `UITests/` |

## Run it

Requires macOS, Xcode 15+, [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
swift test                          # core logic tests
brew install xcodegen && xcodegen generate
open AccessibleNotes.xcodeproj
```

Launch args: `-disableCloudKit` (run without iCloud, e.g. in Simulator without an account), `-uiTesting` (in-memory store, local key).

## Shipping to TestFlight / App Store

1. Change the bundle id and the CloudKit container id (`com.example.accessiblenotes` / `iCloud.com.example.accessiblenotes`)
   in `project.yml` and `PersistenceController.swift` to ones in your Apple Developer account.
2. Enable iCloud (CloudKit) + Push capabilities; deploy the CloudKit schema to Production from the CloudKit Console.
3. Archive → upload → TestFlight. Only after real users install it should user counts go on a résumé.

## Roadmap

Note sharing (CKShare) with per-share keys · Siri/App Intents · attachments · key-recovery flow · VoiceOver user testing with real users.

MIT licensed.
