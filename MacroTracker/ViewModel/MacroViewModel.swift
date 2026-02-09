import SwiftUI
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
            
            for item in ingredients {
                if let nutrients = try await usda.fetchNutrients(query: item.search_term) {
                    let weight = item.estimated_weight_grams > 0 ? item.estimated_weight_grams : 100.0
                    let ratio = weight / 100.0
                    
                    totalP += (nutrients.protein * ratio)
                    totalF += (nutrients.fat * ratio)
                    totalC += (nutrients.carbs * ratio)
                    totalK += (nutrients.kcal * ratio)
                }
            }
            
            return (totalP, totalC, totalF, totalK)
            
        } catch {
            logger.error("Analysis Failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true // Trigger Alert in View
            return nil
        }
    }
    
    func saveMeal(description: String, p: Double, f: Double, c: Double, portion: Double, portionUnit: String, date: Date) {
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
        } catch {
            logger.error("Failed to save context: \(error.localizedDescription)")
            errorMessage = "Failed to save meal to database."
            showError = true
        }
    }
    
    private func combineDate(_ date: Date, withTime time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
        return calendar.date(from: DateComponents(year: dateComponents.year, month: dateComponents.month, day: dateComponents.day, hour: timeComponents.hour, minute: timeComponents.minute, second: timeComponents.second)) ?? date
    }
}
