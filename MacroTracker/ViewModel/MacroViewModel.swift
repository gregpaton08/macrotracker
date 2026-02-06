import SwiftUI
import CoreData
import OSLog

@MainActor
class MacroViewModel: ObservableObject {
    let context: NSManagedObjectContext
    let logger = Logger(subsystem: "com.gpaton08.MacroTracker", category: "ViewModel")
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
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
    
    // MARK: - Logic
    
    // Updated signature
        func saveMeal(description: String, p: Double, f: Double, c: Double, portion: Double, portionUnit: String) {
            let newMeal = MealEntity(context: context)
            newMeal.id = UUID()
            newMeal.timestamp = Date()
            newMeal.summary = description
            
            // Macros
            newMeal.totalProtein = p
            newMeal.totalFat = f
            newMeal.totalCarbs = c
            
            // NEW: Semantic Naming
            newMeal.portion = portion
            newMeal.portionUnit = portionUnit
            
            saveContext()
        }
    
    /// Orchestrates the AI + USDA flow
    func calculateMacros(description: String) async -> (p: Double, c: Double, f: Double, k: Double)? {
        setupClients() // Refresh keys
        
        guard let gemini = geminiClient, let usda = usdaClient else {
            errorMessage = "Missing API Keys. Please check Settings."
            return nil
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            logger.debug("Starting Analysis for: \(description)")
            
            // 1. Gemini: Parse Input into Ingredients
            let ingredients = try await gemini.parseInput(userText: description)
            
            var totalP = 0.0
            var totalC = 0.0
            var totalF = 0.0
            var totalK = 0.0
            
            // 2. USDA: Fetch & Sum for each ingredient
            for item in ingredients {
                logger.debug("Fetching USDA for: \(item.search_term)")
                
                if let nutrients = try await usda.fetchNutrients(query: item.search_term) {
                    // USDA returns values per 100g.
                    // If Gemini gave us a weight, use it. Otherwise assume 100g.
                    let weight = item.estimated_weight_grams > 0 ? item.estimated_weight_grams : 100.0
                    let ratio = weight / 100.0
                    
                    totalP += (nutrients.protein * ratio)
                    totalF += (nutrients.fat * ratio)
                    totalC += (nutrients.carbs * ratio)
                    totalK += (nutrients.kcal * ratio)
                }
            }
            
            logger.notice("Total Calculated: P:\(totalP) C:\(totalC) F:\(totalF)")
            return (totalP, totalC, totalF, totalK)
            
        } catch {
            logger.error("Analysis Failed: \(error.localizedDescription)")
            errorMessage = "Failed to analyze food."
            return nil
        }
    }
    
    private func saveContext() {
        do {
            try context.save()
        } catch {
            logger.error("Failed to save context: \(error.localizedDescription)")
        }
    }
}
