//
//  Persistence.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/26/26.
//
//  CoreData stack using NSPersistentCloudKitContainer for automatic
//  iCloud sync. Auto-migration is enabled. Merge policy is
//  "property object trump" (local changes win on conflict).
//

import CoreData
import OSLog

class PersistenceController {
  static let shared = PersistenceController()

  private let logger = Logger(subsystem: "com.macrotracker", category: "Persistence")
  let container: NSPersistentCloudKitContainer

  /// Non-nil if the persistent store failed to load. Checked by the app entry point
  /// to display a fallback error screen instead of the main UI.
  var loadError: NSError?

  /// - Parameter inMemory: When `true`, uses `/dev/null` as the store URL
  ///   so data is never written to disk (useful for SwiftUI previews and tests).
  init(inMemory: Bool = false) {
    container = NSPersistentCloudKitContainer(name: "MacroTracker")

    // Enable lightweight auto-migration
    let description = container.persistentStoreDescriptions.first
    description?.shouldMigrateStoreAutomatically = true
    description?.shouldInferMappingModelAutomatically = true

    if inMemory {
      container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
    }

    // Merge remote CloudKit changes automatically; local edits take priority
    container.viewContext.automaticallyMergesChangesFromParent = true
    container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

    container.loadPersistentStores { [self] (storeDescription, error) in
      if let error = error as NSError? {
        logger.error("CoreData failed to load: \(error), \(error.userInfo)")
        self.loadError = error
      }
    }
  }

  /// Saves the view context if it has pending changes.
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
