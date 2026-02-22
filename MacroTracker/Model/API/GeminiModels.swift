//
//  GeminiModels.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/5/26.
//
//  Codable models for the Google Gemini API.
//  Supports both text-only and multimodal (image) requests.
//

import Foundation

// MARK: - Request

/// Wraps the body sent to the Gemini `generateContent` endpoint.
struct GeminiRequest: Codable {
    struct Content: Codable { var parts: [Part] }

    /// A single content part — either text, inline image data, or both.
    struct Part: Codable {
        var text: String?
        var inlineData: InlineData?
    }

    /// Base64-encoded binary payload for multimodal requests (e.g. JPEG photo).
    struct InlineData: Codable {
        let mimeType: String
        let data: String      // base64-encoded
    }

    struct GenerationConfig: Codable { var response_mime_type: String }

    let contents: [Content]
    let generationConfig: GenerationConfig
}

// MARK: - Response

/// Thin wrapper around the Gemini API response.
struct GeminiResponse: Codable {
    struct Candidate: Codable { var content: Content }
    struct Content: Codable { var parts: [Part] }
    struct Part: Codable { var text: String }

    let candidates: [Candidate]?
}

// MARK: - Direct AI Analysis Result

/// One-shot macro analysis returned by `GeminiClient.analyzeFood`.
struct AIAnalysisResult: Codable {
    let summary: String
    let total_calories: Double
    let total_protein: Double
    let total_carbs: Double
    let total_fat: Double

    /// Optional breakdown for transparency.
    let items: [FoodItem]

    struct FoodItem: Codable {
        let name: String
        let estimated_calories: Double
    }
}

// MARK: - Nutrition Label Scan Result

/// Structured data extracted from a photographed nutrition facts label.
/// All macro fields default to `0` if not visible on the label.
struct ParsedNutritionLabel: Codable {
    let description: String?     // Food name from the label, if visible
    let serving_size: String?    // Numeric value, e.g. "28"
    let serving_unit: String?    // Unit, e.g. "g", "ml", "oz"
    let calories: Double?
    let protein_grams: Double
    let fat_grams: Double
    let carbs_grams: Double
}
