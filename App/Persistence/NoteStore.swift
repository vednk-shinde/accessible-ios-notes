import CoreData
import NotesCore
import SwiftUI

/// Bridges encrypted Core Data rows and decrypted `NoteSnapshot`s for the UI.
@MainActor
final class NoteStore: ObservableObject {
    @Published private(set) var notes: [NoteSnapshot] = []
    @Published var lastError: String?

    private let persistence: PersistenceController
    private let crypto: NoteCrypto
    private var observer: NSObjectProtocol?

    init(persistence: PersistenceController, crypto: NoteCrypto) {
        self.persistence = persistence
        self.crypto = crypto
        reload()
        // Refresh whenever CloudKit imports changes from another device.
        observer = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextObjectsDidChange,
            object: persistence.container.viewContext, queue: .main
        ) { [weak self] _ in Task { @MainActor in self?.reload() } }
    }

    deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }

    private var context: NSManagedObjectContext { persistence.container.viewContext }

    func reload() {
        let request = NSFetchRequest<NSManagedObject>(entityName: PersistenceController.entityName)
        do {
            let rows = try context.fetch(request)
            let decoded = rows.compactMap(snapshot(from:))
            notes = NoteOrdering.sorted(decoded)
        } catch {
            lastError = "Couldn't load notes: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func createNote() -> NoteSnapshot {
        let note = NoteSnapshot(title: "", body: "")
        let row = NSEntityDescription.insertNewObject(forEntityName: PersistenceController.entityName, into: context)
        row.setValue(note.id, forKey: "id")
        write(note, to: row)
        save()
        return note
    }

    func update(_ note: NoteSnapshot) {
        guard let row = fetchRow(id: note.id) else { return }
        var edited = note
        edited.updatedAt = Date()
        write(edited, to: row)
        save()
    }

    func togglePin(_ note: NoteSnapshot) {
        var n = note
        n.isPinned.toggle()
        update(n)
    }

    func delete(_ note: NoteSnapshot) {
        guard let row = fetchRow(id: note.id) else { return }
        context.delete(row)
        save()
    }

    // MARK: - Private

    private func fetchRow(id: UUID) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: PersistenceController.entityName)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    private func write(_ note: NoteSnapshot, to row: NSManagedObject) {
        let ctx = note.id.uuidString
        do {
            row.setValue(try crypto.seal(note.title, context: ctx), forKey: "titleCipher")
            row.setValue(try crypto.seal(note.body, context: ctx), forKey: "bodyCipher")
        } catch {
            lastError = "Couldn't encrypt note: \(error.localizedDescription)"
        }
        row.setValue(note.updatedAt, forKey: "updatedAt")
        row.setValue(note.isPinned, forKey: "isPinned")
    }

    private func snapshot(from row: NSManagedObject) -> NoteSnapshot? {
        guard let id = row.value(forKey: "id") as? UUID,
              let t = row.value(forKey: "titleCipher") as? Data,
              let b = row.value(forKey: "bodyCipher") as? Data,
              let title = try? crypto.open(t, context: id.uuidString),
              let body = try? crypto.open(b, context: id.uuidString)
        else { return nil } // undecryptable rows (e.g. key not yet synced) are skipped, not shown as garbage
        return NoteSnapshot(
            id: id, title: title, body: body,
            updatedAt: row.value(forKey: "updatedAt") as? Date ?? .distantPast,
            isPinned: row.value(forKey: "isPinned") as? Bool ?? false
        )
    }

    private func save() {
        guard context.hasChanges else { reload(); return }
        do { try context.save() } catch {
            lastError = "Couldn't save: \(error.localizedDescription)"
            context.rollback()
        }
        reload()
    }
}
