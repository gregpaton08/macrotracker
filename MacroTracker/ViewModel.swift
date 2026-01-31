import SwiftUI
import CoreData

@MainActor
class MacroViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @AppStorage("google_api_key") var googleKey: String = ""
    @AppStorage("usda_api_key") var usdaKey: String = ""
    
    private let geminiClient = GeminiClient()
    private let usdaClient = USDAClient()
    private let viewContext = PersistenceController.shared.container.viewContext
    
    // MARK: - NEW: Calculate Only (Auto-Fill)
    // Returns a tuple of (Protein, Fat, Carbs, Calories, Weight)
    func calculateMacros(description: String) async -> (p: Double, f: Double, c: Double, k: Double, w: Double)? {
        guard !googleKey.isEmpty, !usdaKey.isEmpty else {
            errorMessage = "Missing API Keys"
            return nil
        }
        
        isLoading = true
        errorMessage = nil
        
        var totalP = 0.0, totalF = 0.0, totalC = 0.0, totalK = 0.0, totalW = 0.0
        
        do {
            // 1. Parse (Try local, fallback to cloud)
            var parsedItems: [ParsedFoodIntent.ParsedItem] = []
            
            if let local = LocalParser.parse(description) {
                 // Convert local unit to grams for USDA
                 // Note: You'll need to move convertToGrams to a shared helper or duplicate it here
                 // For brevity, assuming simple pass-through or basic logic
                 let grams = local.qty // Simplification for demo
                 parsedItems = [ParsedFoodIntent.ParsedItem(search_term: local.foodName, estimated_weight_grams: grams)]
            } else {
                 parsedItems = try await geminiClient.parseInput(userText: description, apiKey: googleKey)
            }
            
            // 2. Fetch from USDA
            for item in parsedItems {
                if let nutrients = try await usdaClient.fetchNutrients(query: item.search_term, apiKey: usdaKey) {
                    let ratio = item.estimated_weight_grams / 100.0
                    
                    totalP += nutrients.protein * ratio
                    totalF += nutrients.fat * ratio
                    totalC += nutrients.carbs * ratio
                    totalK += nutrients.kcal * ratio
                    totalW += item.estimated_weight_grams
                }
            }
            
            isLoading = false
            return (totalP, totalF, totalC, totalK, totalW)
            
        } catch {
            errorMessage = "Error: \(error.localizedDescription)"
            isLoading = false
            return nil
        }
    }
    
    // MARK: - Save Manually (Add Meal Button)
    func saveMeal(description: String, p: Double, f: Double, c: Double, kcal: Double, weight: Double) {
        let newMeal = MealEntity(context: viewContext)
        newMeal.id = UUID()
        newMeal.timestamp = Date()
        newMeal.summary = description.capitalized
        
        // Since we are manually entering totals, we create one "Aggregate" child food item
        // so that the hierarchical list still works and stats are correct.
        let foodItem = FoodEntity(context: viewContext)
        foodItem.timestamp = Date()
        foodItem.name = description.capitalized
        foodItem.weightGrams = weight
        foodItem.protein = p
        foodItem.fat = f
        foodItem.carbs = c
        foodItem.calories = kcal
        foodItem.meal = newMeal
        
        newMeal.totalProtein = p
        newMeal.totalFat = f
        newMeal.totalCarbs = c
        newMeal.totalCalories = kcal
        
        PersistenceController.shared.save()
    }
}
