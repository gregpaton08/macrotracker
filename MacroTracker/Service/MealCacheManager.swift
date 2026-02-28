//
//  MealCacheManager.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/30/26.
//
//  CRUD operations for CachedMealEntity — the reusable meal templates
//  that power smart autocomplete in AddMealView. Templates are keyed
//  by name (case-insensitive); saving a duplicate only refreshes `lastUsed`.
//

import CoreData
import OSLog
import SwiftUI

@MainActor
struct MealCacheManager {
    static let shared = MealCacheManager()
    private let viewContext = PersistenceController.shared.container.viewContext
    private let logger = Logger(
        subsystem: "com.macrotracker",
        category: "MealCacheManager"
    )

    // MARK: - Save

    /// Saves or touches a meal template keyed by `name` (case-insensitive).
    ///
    /// - If a template with the same name already exists, only `lastUsed` is
    ///   updated so the original macro values remain a static reference.
    /// - If no match exists, a new `CachedMealEntity` is created.
    func cacheMeal(
        name: String,
        p: Double,
        f: Double,
        c: Double,
        portion: String,
        unit: String
    ) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .capitalized
        guard !cleanName.isEmpty else { return }

        let fetch: NSFetchRequest<CachedMealEntity> =
            CachedMealEntity.fetchRequest()
        fetch.predicate = NSPredicate(format: "name ==[cd] %@", cleanName)
        fetch.fetchLimit = 1

        do {
            let results = try viewContext.fetch(fetch)

            if let existing = results.first {
                // MARK: - TEMPLATE EXISTS
                // Logic: Do NOT overwrite macros. Just update 'lastUsed'
                // so it appears at the top of your autocomplete next time.
                existing.lastUsed = Date()

                // We deliberately DO NOT update protein, fat, carbs, etc.
                // This ensures your saved template remains a static reference.

            } else {
                // MARK: - NEW TEMPLATE
                // Only create a new entry if one doesn't exist
                let newEntity = CachedMealEntity(context: viewContext)
                newEntity.name = cleanName
                newEntity.protein = p
                newEntity.fat = f
                newEntity.carbs = c
                newEntity.portionSize = portion
                newEntity.unit = unit
                newEntity.lastUsed = Date()
            }

            try viewContext.save()

        } catch {
            logger.error(
                "Failed to access meal cache: \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Delete

    /// Removes a cached meal template from the persistent store.
    func delete(_ meal: CachedMealEntity) {
        viewContext.delete(meal)
        do {
            try viewContext.save()
        } catch {
            logger.error(
                "Failed to delete cached meal: \(error.localizedDescription)"
            )
        }
    }
}
