import SwiftUI
import UIKit
import CoreData
import OSLog

@MainActor
class MacroViewModel: ObservableObject {
    let context: NSManagedObjectContext
    private let logger = Logger(subsystem: "com.macrotracker", category: "ViewModel")
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false // Controls the alert presentation
    
    private var geminiClient: GeminiClient?
    private var usdaClient: USDAClient?
    
    init(context: NSManagedObjectContext) {
        self.context = context
        setupClients()
    }
    
    private func setupClients() {
        let defaults = UserDefaults.standard
        if let googleKey = defaults.string(forKey: "google_api_key"), !googleKey.isEmpty {
            self.geminiClient = GeminiClient(apiKey: googleKey)
        }
        if let usdaKey = defaults.string(forKey: "usda_api_key"), !usdaKey.isEmpty {
            self.usdaClient = USDAClient(apiKey: usdaKey)
        }
    }
    
    // MARK: - Core Logic
    
    func calculateMacros(description: String) async -> (p: Double, c: Double, f: Double, k: Double)? {
        setupClients() // Refresh keys just in case
        
        // 1. Validation
        guard let gemini = geminiClient, let usda = usdaClient else {
            errorMessage = "API Keys missing. Please add them in Settings."
            showError = true
            return nil
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // 2. Gemini Parse
            let ingredients = try await gemini.parseInput(userText: description)
            if ingredients.isEmpty {
                throw URLError(.cannotParseResponse, userInfo: [NSLocalizedDescriptionKey: "AI could not identify any food items."])
            }
            
            // 3. USDA Lookup
            var totalP = 0.0, totalC = 0.0, totalF = 0.0, totalK = 0.0
            var failedItems: [String] = []

            for item in ingredients {
                do {
                    if let nutrients = try await usda.fetchNutrients(query: item.search_term) {
                        let weight = item.estimated_weight_grams > 0 ? item.estimated_weight_grams : 100.0
                        let ratio = weight / 100.0

                        totalP += (nutrients.protein * ratio)
                        totalF += (nutrients.fat * ratio)
                        totalC += (nutrients.carbs * ratio)
                        totalK += (nutrients.kcal * ratio)
                    } else {
                        failedItems.append(item.search_term)
                    }
                } catch {
                    logger.error("USDA lookup failed for '\(item.search_term)': \(error.localizedDescription)")
                    failedItems.append(item.search_term)
                }
            }

            if failedItems.count == ingredients.count {
                throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "Could not find nutrition data for any ingredients."])
            }

            if !failedItems.isEmpty {
                let missing = failedItems.joined(separator: ", ")
                errorMessage = "Partial results — no data for: \(missing)"
                showError = true
            }

            return (totalP, totalC, totalF, totalK)
            
        } catch {
            logger.error("Analysis Failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true // Trigger Alert in View
            return nil
        }
    }
    
    func scanNutritionLabel(image: UIImage) async -> ParsedNutritionLabel? {
        setupClients()

        guard let gemini = geminiClient else {
            errorMessage = "Gemini API Key missing. Please add it in Settings."
            showError = true
            return nil
        }

        isLoading = true
        defer { isLoading = false }

        do {
            return try await gemini.parseNutritionLabel(image: image)
        } catch {
            logger.error("Label scan failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
            return nil
        }
    }

    @discardableResult
    func saveMeal(description: String, p: Double, f: Double, c: Double, portion: Double, portionUnit: String, date: Date) -> Bool {
        let newMeal = MealEntity(context: context)
        newMeal.id = UUID()
        newMeal.timestamp = combineDate(date, withTime: Date())
        newMeal.summary = description
        newMeal.totalProtein = p
        newMeal.totalFat = f
        newMeal.totalCarbs = c
        newMeal.portion = portion
        newMeal.portionUnit = portionUnit

        do {
            try context.save()
            return true
        } catch {
            logger.error("Failed to save context: \(error.localizedDescription)")
            context.rollback()
            errorMessage = "Failed to save meal. Please try again."
            showError = true
            return false
        }
    }
    
    private func combineDate(_ date: Date, withTime time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
        return calendar.date(from: DateComponents(year: dateComponents.year, month: dateComponents.month, day: dateComponents.day, hour: timeComponents.hour, minute: timeComponents.minute, second: timeComponents.second)) ?? date
    }
}
