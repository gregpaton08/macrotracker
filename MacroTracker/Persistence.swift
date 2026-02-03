//
//  Persistence.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/26/26.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

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
                // In production, handle this error appropriately
//                Logger.log("CoreData Error: \(error), \(error.userInfo)", category: .coreData, level: .error)
            }
        }
    }
    
    func save() {
        let context = container.viewContext
        if context.hasChanges {
            do {
                try context.save()
            } catch {
//                Logger.log("Save Failed: \(error.localizedDescription)", category: .coreData, level: .error)
            }
        }
    }
}
