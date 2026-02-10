//
//  Persistence.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/26/26.
//

import CoreData
import OSLog

class PersistenceController {
    static let shared = PersistenceController()

    private let logger = Logger(subsystem: "com.macrotracker", category: "Persistence")
    let container: NSPersistentCloudKitContainer
    var loadError: NSError?

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "MacroTracker")

        let description = container.persistentStoreDescriptions.first
        description?.shouldMigrateStoreAutomatically = true
        description?.shouldInferMappingModelAutomatically = true

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        // Enable automatic iCloud syncing
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        container.loadPersistentStores { [self] (storeDescription, error) in
            if let error = error as NSError? {
                logger.error("CoreData failed to load: \(error), \(error.userInfo)")
                self.loadError = error
            }
        }
    }
    
    func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                logger.error("CoreData save failed: \(error.localizedDescription)")
            }
        }
    }
}
