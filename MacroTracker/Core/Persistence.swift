//
//  Persistence.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/26/26.
//

import CoreData
import OSLog

struct PersistenceController {
    static let shared = PersistenceController()

    private let logger = Logger(subsystem: "com.macrotracker", category: "Persistence")
    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        // Ensure your .xcdatamodeld file is named "MacroTracker"
        container = NSPersistentCloudKitContainer(name: "MacroTracker")
        
        let description = container.persistentStoreDescriptions.first
        description?.shouldMigrateStoreAutomatically = true // Must be true
        description?.shouldInferMappingModelAutomatically = true // Must be true
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Enable automatic iCloud syncing
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("CoreData failed to load: \(error), \(error.userInfo)")
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
