//
//  MealCacheManager.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/30/26.
//

import CoreData
import SwiftUI

struct MealCacheManager {
    static let shared = MealCacheManager()
    private let viewContext = PersistenceController.shared.container.viewContext
    
    // 1. Save or Update a Meal in the Cache
    func cacheMeal(name: String, p: Double, f: Double, c: Double, k: Double, portion: String, unit: String) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
        
        // Check if exists
        let fetch: NSFetchRequest<CachedMealEntity> = CachedMealEntity.fetchRequest()
        fetch.predicate = NSPredicate(format: "name == %@", cleanName)
        fetch.fetchLimit = 1
        
        do {
            let results = try viewContext.fetch(fetch)
            let entity: CachedMealEntity
            
            if let existing = results.first {
                entity = existing // Update existing
            } else {
                entity = CachedMealEntity(context: viewContext) // Create new
                entity.name = cleanName
            }
            
            // Update values (Learning the latest usage)
            entity.protein = p
            entity.fat = f
            entity.carbs = c
            entity.calories = k
            entity.portionSize = portion
            entity.unit = unit
            entity.lastUsed = Date()
            
            try viewContext.save()
        } catch {
            print("Failed to cache meal: \(error)")
        }
    }
    
    // 2. Delete
    func delete(_ meal: CachedMealEntity) {
        viewContext.delete(meal)
        try? viewContext.save()
    }
}
