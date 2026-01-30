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
    
    func processFoodEntry(text: String) async {
        guard !googleKey.isEmpty, !usdaKey.isEmpty else {
            errorMessage = "Please enter API Keys in settings."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // 1. Create the PARENT Meal
            let newMeal = MealEntity(context: viewContext)
            newMeal.id = UUID()
            newMeal.timestamp = Date()
            newMeal.summary = text.capitalized // Store the original prompt
            
            var mealP = 0.0, mealF = 0.0, mealC = 0.0, mealKcal = 0.0
            
            // 2. Parse Items
            let parsedItems = try await geminiClient.parseInput(userText: text, apiKey: googleKey)
            
            for item in parsedItems {
                if let nutrients = try await usdaClient.fetchNutrients(query: item.search_term, apiKey: usdaKey) {
                    
                    let ratio = item.estimated_weight_grams / 100.0
                    
                    // 3. Create CHILD Ingredient
                    let newFood = FoodEntity(context: viewContext)
                    newFood.timestamp = Date() // Keep timestamp for stats
                    newFood.name = item.search_term.capitalized
                    newFood.weightGrams = item.estimated_weight_grams
                    
                    let p = nutrients.protein * ratio
                    let f = nutrients.fat * ratio
                    let c = nutrients.carbs * ratio
                    let k = nutrients.kcal * ratio
                    
                    newFood.protein = p
                    newFood.fat = f
                    newFood.carbs = c
                    newFood.calories = k
                    
                    // 4. Link to Parent
                    newFood.meal = newMeal
                    
                    // Accumulate Totals for the Parent
                    mealP += p
                    mealF += f
                    mealC += c
                    mealKcal += k
                }
            }
            
            // 5. Set Parent Totals
            newMeal.totalProtein = mealP
            newMeal.totalFat = mealF
            newMeal.totalCarbs = mealC
            newMeal.totalCalories = mealKcal
            
            PersistenceController.shared.save()
            Logger.log("Saved Meal with \(parsedItems.count) ingredients", category: .coreData, level: .success)
            
        } catch {
            errorMessage = "Error: \(error.localizedDescription)"
            Logger.log("Processing Failed: \(error)", category: .ui, level: .error)
        }
        
        isLoading = false
    }
}
