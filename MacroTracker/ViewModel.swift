
import SwiftUI
import CoreData

@MainActor
class MacroViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // BYOK Storage
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
            // 1. Ask Gemini to parse text
            let parsedItems = try await geminiClient.parseInput(userText: text, apiKey: googleKey)
            
            for item in parsedItems {
                // 2. Ask USDA for data per 100g
                if let nutrients = try await usdaClient.fetchNutrients(query: item.search_term, apiKey: usdaKey) {
                    
                    print("nutrients = \(nutrients)")
                    
                    // 3. Calculate actual values based on weight
                    let ratio = item.estimated_weight_grams / 100.0
                    
                    let actualProtein = nutrients.protein * ratio
                    let actualFat = nutrients.fat * ratio
                    let actualCarbs = nutrients.carbs * ratio
                    let actualKcal = nutrients.kcal * ratio
                    
                    // 4. Save to Core Data
                    let newFood = FoodEntity(context: viewContext)
                    newFood.timestamp = Date()
                    newFood.name = item.search_term.capitalized
                    newFood.weightGrams = item.estimated_weight_grams
                    newFood.protein = actualProtein
                    newFood.fat = actualFat
                    newFood.carbs = actualCarbs
                    newFood.calories = actualKcal
                }
            }
            
            PersistenceController.shared.save()
            
        } catch {
            print("processFoodEntry failed: \(error)")
            errorMessage = "Error: \(error.localizedDescription) \(error)"
        }
        
        isLoading = false
    }
}
