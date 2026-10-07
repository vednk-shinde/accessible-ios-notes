import CryptoKit
import NotesCore
import SwiftUI

@main
struct AccessibleNotesApp: App {
    @StateObject private var store: NoteStore

    init() {
        let args = ProcessInfo.processInfo.arguments
        let uiTesting = args.contains("-uiTesting")
        let persistence = PersistenceController(inMemory: uiTesting, cloudKit: !args.contains("-disableCloudKit"))
        // Key lives in the (iCloud) Keychain; UI tests use a local, non-synced key.
        let keyStore = KeychainKeyStore(synchronizable: !uiTesting)
        let key: SymmetricKey
        if let stored = try? keyStore.loadOrCreateKey() {
            key = stored
        } else if uiTesting {
            // Unsigned simulator builds (CI) may have no Keychain access: use an ephemeral key.
            key = NoteCrypto.generateKey()
        } else {
            fatalError("Unable to access the encryption key in the Keychain")
        }
        _store = StateObject(wrappedValue: NoteStore(persistence: persistence, crypto: NoteCrypto(key: key)))
    }

    var body: some Scene {
        WindowGroup {
            NoteListView()
                .environmentObject(store)
        }
    }
}
