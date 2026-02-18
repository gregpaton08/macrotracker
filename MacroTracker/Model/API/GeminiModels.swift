//
//  GeminiModels.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/5/26.
//

import Foundation

// MARK: - Gemini API Request/Response
struct GeminiRequest: Codable {
    struct Content: Codable { var parts: [Part] }
    struct Part: Codable {
        var text: String?
        var inlineData: InlineData?
    }
    struct InlineData: Codable {
        let mimeType: String
        let data: String
    }
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

// MARK: - The "Direct" AI Analysis Result
// We ask Gemini to fill THIS struct directly.
struct AIAnalysisResult: Codable {
    let summary: String        // e.g. "Chicken and Rice"
    let total_calories: Double
    let total_protein: Double
    let total_carbs: Double
    let total_fat: Double
    
    // Optional: Breakdown for transparency
    let items: [FoodItem]
    
    struct FoodItem: Codable {
        let name: String
        let estimated_calories: Double
    }
}

// The Strict Schema for Gemini
struct ParsedFoodIntent: Codable {
    let items: [ParsedItem]

    struct ParsedItem: Codable {
        let search_term: String
        let estimated_weight_grams: Double
    }
}

// MARK: - Nutrition Label Response
struct ParsedNutritionLabel: Codable {
    let description: String?
    let serving_size: String?
    let serving_unit: String?
    let calories: Double?
    let protein_grams: Double
    let fat_grams: Double
    let carbs_grams: Double
}
