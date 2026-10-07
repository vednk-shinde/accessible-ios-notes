import CryptoKit
import Foundation

public enum NoteCryptoError: Error, Equatable {
    case invalidUTF8
    case corruptedCiphertext
}

/// Client-side authenticated encryption (AES-256-GCM) for note content.
///
/// Notes are encrypted *before* they reach Core Data, so what CloudKit syncs is
/// ciphertext only: Apple's servers never see note text.
public struct NoteCrypto {
    private let key: SymmetricKey

    public init(key: SymmetricKey) { self.key = key }

    public static func generateKey() -> SymmetricKey { SymmetricKey(size: .bits256) }

    /// Encrypts `text`; the returned blob is `nonce || ciphertext || tag`.
    /// `context` (e.g. the note id) is bound as authenticated data so a blob
    /// can't be swapped between notes undetected.
    public func seal(_ text: String, context: String = "") throws -> Data {
        let box = try AES.GCM.seal(Data(text.utf8), using: key, authenticating: Data(context.utf8))
        guard let combined = box.combined else { throw NoteCryptoError.corruptedCiphertext }
        return combined
    }

    public func open(_ blob: Data, context: String = "") throws -> String {
        let plain: Data
        do {
            let box = try AES.GCM.SealedBox(combined: blob)
            plain = try AES.GCM.open(box, using: key, authenticating: Data(context.utf8))
        } catch {
            throw NoteCryptoError.corruptedCiphertext
        }
        guard let text = String(data: plain, encoding: .utf8) else { throw NoteCryptoError.invalidUTF8 }
        return text
    }
}
