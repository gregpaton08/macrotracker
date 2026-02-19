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
    
    init(context: NSManagedObjectContext) {
        self.context = context
        setupClient()
    }
    
    private func setupClient() {
        let defaults = UserDefaults.standard
        if let googleKey = defaults.string(forKey: "google_api_key"), !googleKey.isEmpty {
            self.geminiClient = GeminiClient(apiKey: googleKey)
        }
    }
    
    // MARK: - Core Logic (Simplified)
    
    func calculateMacros(description: String) async -> (p: Double, c: Double, f: Double, k: Double)? {
        setupClient()
        
        guard let gemini = geminiClient else {
            errorMessage = "Google API Key missing. Please check Settings."
            showError = true
            return nil
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            // SINGLE CALL - Much faster
            let result = try await gemini.analyzeFood(userText: description)
            
            return (
                result.total_protein,
                result.total_carbs,
                result.total_fat,
                result.total_calories
            )
            
        } catch {
            logger.error("AI Analysis Failed: \(error.localizedDescription)")
            errorMessage = "Could not analyze food. Please try again. \(error.localizedDescription)"
            showError = true
            return nil
        }
    }
    
    func scanNutritionLabel(image: UIImage) async -> ParsedNutritionLabel? {
        setupClient()

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
    
    // ... (keep saveMeal and combineDate exactly as they were) ...
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
            context.rollback()
            errorMessage = "Failed to save meal."
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
