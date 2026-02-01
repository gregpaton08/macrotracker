import SwiftUI
import CoreData

@MainActor
class MacroViewModel: ObservableObject {
    let context: NSManagedObjectContext
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // API Clients (Placeholder for your actual implementation)
    // private let gemini = GeminiClient()
    // private let usda = USDAClient()
    
    // MARK: - THE FIX: Explicit Initializer
    init(context: NSManagedObjectContext) {
        self.context = context
    }
    
    // MARK: - Logic
    
    func saveMeal(description: String, p: Double, f: Double, c: Double, kcal: Double, weight: Double) {
        let newMeal = MealEntity(context: context)
        newMeal.id = UUID()
        newMeal.timestamp = Date()
        newMeal.summary = description
        
        // Save Totals
        newMeal.totalCalories = kcal
        newMeal.totalProtein = p
        newMeal.totalFat = f
        newMeal.totalCarbs = c
        
        // Create Ingredient (Child)
        let ingredient = FoodEntity(context: context)
        ingredient.name = description
        ingredient.weightGrams = weight
        ingredient.calories = kcal
        ingredient.protein = p
        ingredient.fat = f
        ingredient.carbs = c
        ingredient.meal = newMeal
        
        saveContext()
    }
    
    func calculateMacros(description: String) async -> (p: Double, c: Double, f: Double, k: Double)? {
        isLoading = true
        defer { isLoading = false }
        
        // Simulating API Call for now (Replace with your actual Gemini/USDA call)
        // If you already have the API logic, keep it! Just ensure the init() matches.
        try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
        
        // Dummy return for testing UI
        return (30.0, 45.0, 10.0, 400.0)
    }
    
    private func saveContext() {
        do {
            try context.save()
        } catch {
            errorMessage = "Failed to save meal: \(error.localizedDescription)"
        }
    }
}
