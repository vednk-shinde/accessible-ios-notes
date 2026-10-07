import CoreData

/// Core Data stack. The model is built in code (no .xcdatamodeld) so the schema is
/// reviewable in diffs. With `cloudKit: true` the store mirrors to the user's
/// private CloudKit database via `NSPersistentCloudKitContainer`.
final class PersistenceController {
    static let cloudKitContainerID = "iCloud.com.example.accessiblenotes"
    static let entityName = "NoteEntity"

    let container: NSPersistentContainer

    init(inMemory: Bool = false, cloudKit: Bool = true) {
        let model = Self.makeModel()
        if cloudKit && !inMemory {
            container = NSPersistentCloudKitContainer(name: "AccessibleNotes", managedObjectModel: model)
        } else {
            container = NSPersistentContainer(name: "AccessibleNotes", managedObjectModel: model)
        }

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Missing persistent store description")
        }
        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        } else if cloudKit {
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(containerIdentifier: Self.cloudKitContainerID)
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
        }

        container.loadPersistentStores { _, error in
            if let error { fatalError("Core Data failed to load: \(error)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    static let preview = PersistenceController(inMemory: true, cloudKit: false)

    /// CloudKit requires every attribute to be optional or have a default, and no
    /// uniqueness constraints. Note text is stored only as AES-GCM ciphertext.
    private static func makeModel() -> NSManagedObjectModel {
        func attr(_ name: String, _ type: NSAttributeType, optional: Bool = true, defaultValue: Any? = nil) -> NSAttributeDescription {
            let a = NSAttributeDescription()
            a.name = name
            a.attributeType = type
            a.isOptional = optional
            a.defaultValue = defaultValue
            return a
        }
        let entity = NSEntityDescription()
        entity.name = entityName
        entity.managedObjectClassName = NSStringFromClass(NSManagedObject.self)
        entity.properties = [
            attr("id", .UUIDAttributeType),
            attr("titleCipher", .binaryDataAttributeType),
            attr("bodyCipher", .binaryDataAttributeType),
            attr("updatedAt", .dateAttributeType),
            attr("isPinned", .booleanAttributeType, optional: false, defaultValue: false),
        ]
        let model = NSManagedObjectModel()
        model.entities = [entity]
        return model
    }
}
