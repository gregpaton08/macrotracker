//
//  Models.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/26/26.
//

import Foundation

// MARK: - Internal App Models
struct FoodItem: Identifiable, Codable {
    let id: UUID
    let name: String
    let calories: Double
    let protein: Double
    let fat: Double
    let carbs: Double
    let weightGrams: Double
}

// MARK: - Gemini API Request/Response
struct GeminiRequest: Codable {
    struct Content: Codable { var parts: [Part] }
    struct Part: Codable { var text: String }
    struct GenerationConfig: Codable { var response_mime_type: String }
    
    let contents: [Content]
    let generationConfig: GenerationConfig
}

struct GeminiResponse: Codable {
    struct Candidate: Codable { var content: Content }
    struct Content: Codable { var parts: [Part] }
    struct Part: Codable { var text: String }
    
    let candidates: [Candidate]?
}

// The JSON Schema we force Gemini to return
struct ParsedFoodIntent: Codable {
    let items: [ParsedItem]
    
    struct ParsedItem: Codable {
        let search_term: String // Optimized for USDA search (e.g., "Raw Apple")
        let estimated_weight_grams: Double // AI handles the unit conversion logic
    }
}

// MARK: - USDA API Response
struct USDAFoodSearchResponse: Codable {
    let foods: [USDAFood]
}

struct USDAFood: Codable {
    let fdcId: Int
    let description: String
    let foodNutrients: [USDANutrient]
}

struct USDANutrient: Codable {
    let nutrientId: Int
    let value: Double // Per 100g usually
}
