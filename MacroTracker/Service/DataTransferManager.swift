//
//  DataTransferManager.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/8/26.
//

import Foundation
import CoreData
import SwiftUI

// MARK: - JSON Models
struct AppDataExport: Codable {
    let version: Int
    let exportedAt: Date
    let meals: [MealExport]
    let savedTemplates: [SavedTemplateExport]
}

struct MealExport: Codable {
    let id: UUID?
    let timestamp: Date
    let summary: String
    let protein: Double
    let carbs: Double
    let fat: Double
    let portion: Double
    let unit: String
}

struct SavedTemplateExport: Codable {
    let name: String
    let protein: Double
    let carbs: Double
    let fat: Double
    let portion: String
    let unit: String
    let lastUsed: Date?
}

// MARK: - Manager Class
class DataTransferManager: ObservableObject {
    static let shared = DataTransferManager()
    private let context = PersistenceController.shared.container.viewContext
    
    // MARK: - Export Logic
    func generateJSON() -> URL? {
        // 1. Fetch All Logged Meals
        let mealRequest: NSFetchRequest<MealEntity> = MealEntity.fetchRequest()
        let meals = (try? context.fetch(mealRequest)) ?? []
        
        let mealExports = meals.map { meal in
            MealExport(
                id: meal.id,
                timestamp: meal.timestamp ?? Date(),
                summary: meal.summary ?? "Unknown",
                protein: meal.totalProtein,
                carbs: meal.totalCarbs,
                fat: meal.totalFat,
                portion: meal.portion,
                unit: meal.portionUnit ?? "g"
            )
        }
        
        // 2. Fetch All Saved Templates
        let cacheRequest: NSFetchRequest<CachedMealEntity> = CachedMealEntity.fetchRequest()
        let templates = (try? context.fetch(cacheRequest)) ?? []
        
        let templateExports = templates.map { temp in
            SavedTemplateExport(
                name: temp.name ?? "Unknown",
                protein: temp.protein,
                carbs: temp.carbs,
                fat: temp.fat,
                portion: temp.portionSize ?? "100",
                unit: temp.unit ?? "g",
                lastUsed: temp.lastUsed
            )
        }
        
        // 3. Encode to JSON
        let exportData = AppDataExport(
            version: 1,
            exportedAt: Date(),
            meals: mealExports,
            savedTemplates: templateExports
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(exportData)
            
            // 4. Save to Temporary File
            let fileName = "MacroTracker_Backup_\(Int(Date().timeIntervalSince1970)).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try data.write(to: tempURL)
            return tempURL
        } catch {
            print("Export Failed: \(error)")
            return nil
        }
    }
    
    // MARK: - Import Logic
    func importJSON(from url: URL) async throws -> Int {
        // 1. Read & Decode
        // (Security scoped resource access is handled by the View modifier usually, but good practice to check)
        let _ = url.startAccessingSecurityScopedResource()
        defer { url.stopAccessingSecurityScopedResource() }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let importData = try decoder.decode(AppDataExport.self, from: data)
        var count = 0
        
        // 2. Perform Import on Background Context to avoid freezing UI
        try await context.perform {
            // A. Import Meals (Check for duplicates by ID)
            for item in importData.meals {
                if !self.mealExists(id: item.id) {
                    let newMeal = MealEntity(context: self.context)
                    newMeal.id = item.id ?? UUID()
                    newMeal.timestamp = item.timestamp
                    newMeal.summary = item.summary
                    newMeal.totalProtein = item.protein
                    newMeal.totalCarbs = item.carbs
                    newMeal.totalFat = item.fat
                    newMeal.portion = item.portion
                    newMeal.portionUnit = item.unit
                    count += 1
                }
            }
            
            // B. Import Templates (Merge using CacheManager logic)
            for item in importData.savedTemplates {
                // Using existing manager logic ensures we don't create duplicate templates
                MealCacheManager.shared.cacheMeal(
                    name: item.name,
                    p: item.protein,
                    f: item.fat,
                    c: item.carbs,
                    portion: item.portion,
                    unit: item.unit
                )
            }
            
            // C. Save
            if self.context.hasChanges {
                try self.context.save()
            }
        }
        return count
    }
    
    private func mealExists(id: UUID?) -> Bool {
        guard let id = id else { return false }
        let fetch: NSFetchRequest<MealEntity> = MealEntity.fetchRequest()
        fetch.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetch.fetchLimit = 1
        return (try? context.count(for: fetch)) ?? 0 > 0
    }
}
