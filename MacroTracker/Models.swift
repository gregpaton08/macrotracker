//
//  Models.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/26/26.
//

import Foundation

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

// The Strict Schema for Gemini
struct ParsedFoodIntent: Codable {
    let items: [ParsedItem]
    
    struct ParsedItem: Codable {
        let search_term: String
        let estimated_weight_grams: Double
    }
}

// MARK: - USDA API Response (Defensive Version)
struct USDAFoodSearchResponse: Codable {
    // OPTIONAL: Prevents crash if USDA returns an error object instead of food list
    let foods: [USDAFood]?
}

struct USDAFood: Codable {
    let fdcId: Int?
    let description: String?
    let foodNutrients: [USDANutrient]?
}

struct USDANutrient: Codable {
    let nutrientId: Int?
    let value: Double? // OPTIONAL: Sometimes null in USDA database
}
