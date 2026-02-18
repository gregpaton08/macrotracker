//
//  GeminiClient.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/5/26.
//

import Foundation
import UIKit
import OSLog

struct ApiResponse: Codable {
    let message: String
}

// MARK: - Gemini Client
class GeminiClient {
    private let session = URLSession.shared
    private let logger = Logger(subsystem: "com.macrotracker", category: "GeminiClient")

    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    // MARK: - Direct Analysis
    func analyzeFood(userText: String) async throws -> AIAnalysisResult {
        // Use a fast, smart model
        let model = "gemini-2.0-flash"
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        // The "One-Shot" Prompt
        let promptText = """
        You are a nutritionist. Analyze this food log: "\(userText)".
        
        1. Identify the food items and estimate portion sizes if not specified.
        2. Calculate the total macronutrients (Protein, Fat, Carbs) and Calories.
        3. Return ONLY valid JSON matching this schema:
        {
            "summary": "Short readable summary of food",
            "total_calories": number,
            "total_protein": number (grams),
            "total_carbs": number (grams),
            "total_fat": number (grams),
            "items": [
                { "name": "Item Name", "estimated_calories": number }
            ]
        }
        """
        
        let requestBody = GeminiRequest(
            contents: [.init(parts: [.init(text: promptText)])],
            generationConfig: .init(response_mime_type: "application/json")
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        // Error Handling
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            self.logger.error("HTTP Error: \(httpResponse.statusCode)")
            throw URLError(.badServerResponse)
        }
        
        // Decode Gemini Wrapper
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        
        guard var jsonText = geminiResponse.candidates?.first?.content.parts.first?.text else {
            throw URLError(.cannotParseResponse)
        }
        
        // Clean Markdown if present
        jsonText = jsonText
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Decode Final Result
        guard let cleanData = jsonText.data(using: .utf8) else { throw URLError(.cannotParseResponse) }
        
        let result = try JSONDecoder().decode(AIAnalysisResult.self, from: cleanData)
        return result
    }

    func parseInput(userText: String) async throws -> [ParsedFoodIntent.ParsedItem] {

        // TODO: allow user to select model based on what is available.
//        let model = "gemini-pro-latest"
//        let model = "gemini-2.0-flash"
        let model = "gemini-3-flash-preview"
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        logger.debug("Parsing: '\(userText)'")

        // TODO: improve prompt. Include portion size if provided. Maybe rethink the RAG approach.
        let prompt = """
        Analyze this food description for searching the USDA database for macronutrients: "\(userText)".
        Complex foods should be broken down into a list of ingredients.
        Return ONLY valid JSON. Do not use Markdown formatting.
        Schema:
        { "items": [ { "search_term": "string (USDA database optimized)", "estimated_weight_grams": number } ] }
        """

        let requestBody = GeminiRequest(
            contents: [.init(parts: [.init(text: prompt, inlineData: nil)])],
            generationConfig: .init(response_mime_type: "application/json")
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)
//        Logger.logResponse(data: data, response: response, error: nil, category: .gemini)

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 429 {
                self.logger.warning("Rate Limited.")
                throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "Rate limited by Gemini API. Please try again shortly."])
            }
            if httpResponse.statusCode != 200 {
                self.logger.error("Received HTTP response: \(httpResponse.statusCode)")

                if let decodedData = try? JSONDecoder().decode(ApiResponse.self, from: data) {
                    let userInfo: [String: Any] = [NSLocalizedDescriptionKey: decodedData.message]
                    throw URLError(.badServerResponse, userInfo: userInfo)
                }
                throw URLError(.badServerResponse)
            }
        }

        // Clean and Decode
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard var jsonText = geminiResponse.candidates?.first?.content.parts.first?.text else {
            throw URLError(.cannotParseResponse)
        }

        // Strip Markdown
        jsonText = jsonText.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
        logger.debug("jsonText = \(jsonText)")

        guard let cleanData = jsonText.data(using: .utf8) else { throw URLError(.cannotParseResponse) }
        let result = try JSONDecoder().decode(ParsedFoodIntent.self, from: cleanData).items


        logger.debug("result: \(result)")
        return result
    }

    // MARK: - Nutrition Label Scanning

    func parseNutritionLabel(image: UIImage) async throws -> ParsedNutritionLabel {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw URLError(.cannotParseResponse, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image to JPEG."])
        }
        let base64String = jpegData.base64EncodedString()

        let model = "gemini-3-flash-preview"
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        let prompt = """
        Analyze this nutrition facts label photo and extract the macronutrient information.
        Return ONLY valid JSON with this schema:
        {
          "description": "food name from the label if visible, otherwise null",
          "serving_size": "numeric serving size value as a string (e.g. \"28\"), or null if not visible",
          "serving_unit": "serving unit (e.g. \"g\", \"ml\", \"oz\"), or null if not visible",
          "calories": number or null,
          "protein_grams": number,
          "fat_grams": number,
          "carbs_grams": number
        }
        Extract the values exactly as printed on the label. If a macro value is not visible, use 0.
        """

        let requestBody = GeminiRequest(
            contents: [.init(parts: [
                .init(text: prompt, inlineData: nil),
                .init(text: nil, inlineData: .init(mimeType: "image/jpeg", data: base64String))
            ])],
            generationConfig: .init(response_mime_type: "application/json")
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 429 {
                self.logger.warning("Rate Limited.")
                throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: "Rate limited by Gemini API. Please try again shortly."])
            }
            if httpResponse.statusCode != 200 {
                self.logger.error("Received HTTP response: \(httpResponse.statusCode)")

                if let decodedData = try? JSONDecoder().decode(ApiResponse.self, from: data) {
                    let userInfo: [String: Any] = [NSLocalizedDescriptionKey: decodedData.message]
                    throw URLError(.badServerResponse, userInfo: userInfo)
                }
                throw URLError(.badServerResponse)
            }
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard var jsonText = geminiResponse.candidates?.first?.content.parts.first?.text else {
            throw URLError(.cannotParseResponse, userInfo: [NSLocalizedDescriptionKey: "Could not read the nutrition label. Try a clearer photo."])
        }

        jsonText = jsonText.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
        logger.debug("Nutrition label JSON: \(jsonText)")

        guard let cleanData = jsonText.data(using: .utf8) else {
            throw URLError(.cannotParseResponse, userInfo: [NSLocalizedDescriptionKey: "Could not parse the nutrition label response."])
        }

        return try JSONDecoder().decode(ParsedNutritionLabel.self, from: cleanData)
    }
}
