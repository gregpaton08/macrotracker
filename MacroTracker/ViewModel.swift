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
            let parsedItems = try await geminiClient.parseInput(userText: text, apiKey: googleKey)
            
            for item in parsedItems {
                if let nutrients = try await usdaClient.fetchNutrients(query: item.search_term, apiKey: usdaKey) {
                    
                    let ratio = item.estimated_weight_grams / 100.0
                    
                    let newFood = FoodEntity(context: viewContext)
                    newFood.timestamp = Date()
                    newFood.name = item.search_term.capitalized
                    newFood.weightGrams = item.estimated_weight_grams
                    newFood.protein = nutrients.protein * ratio
                    newFood.fat = nutrients.fat * ratio
                    newFood.carbs = nutrients.carbs * ratio
                    newFood.calories = nutrients.kcal * ratio
                }
            }
            PersistenceController.shared.save()
            Logger.log("Successfully saved food items.", category: .coreData, level: .success)
            
        } catch {
            errorMessage = "Error: \(error.localizedDescription)"
            Logger.log("Processing Failed: \(error)", category: .ui, level: .error)
        }
        
        isLoading = false
    }
}
