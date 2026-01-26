//
//  APIClients.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/26/26.
//

import Foundation

// MARK: - Gemini Client
class GeminiClient {
    private let session = URLSession.shared
    
    func parseInput(userText: String, apiKey: String) async throws -> [ParsedFoodIntent.ParsedItem] {
        // Updated to Gemini 2.5 Flash (Current Stable)
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }
        
        // Prompt Engineering: We ask the LLM to do the heavy lifting on unit conversion
        let prompt = """
        Analyze this food log: "\(userText)".
        Return a JSON object with a list of items.
        For each item:
        1. "search_term": A clean search query for a USDA database (e.g. "Grilled Chicken Breast").
        2. "estimated_weight_grams": Estimate the weight in grams based on the description (e.g., "1 cup" -> 150).
        """
        
        let requestBody = GeminiRequest(
            contents: [.init(parts: [.init(text: prompt)])],
            generationConfig: .init(response_mime_type: "application/json")
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "No error text"
            print("🛑 Gemini Error Body: \(errorText)")
            throw URLError(.badServerResponse)
        }
        
        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let jsonText = geminiResponse.candidates?.first?.content.parts.first?.text,
              let data = jsonText.data(using: .utf8) else {
            throw URLError(.cannotParseResponse)
        }
        
        let result = try JSONDecoder().decode(ParsedFoodIntent.self, from: data)
        return result.items
    }
}

// MARK: - USDA Client
class USDAClient {
    // Standard Nutrient IDs
    private let PROTEIN_ID = 203
    private let FAT_ID = 204
    private let CARBS_ID = 205
    private let KCAL_ID = 208
    
    func fetchNutrients(query: String, apiKey: String) async throws -> (protein: Double, fat: Double, carbs: Double, kcal: Double)? {
        // Query for Foundation or SR Legacy foods for best data accuracy
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.nal.usda.gov/fdc/v1/foods/search?query=\(encodedQuery)&dataType=Foundation,SR%20Legacy&pageSize=1&api_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else { return nil }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(USDAFoodSearchResponse.self, from: data)
        
        guard let food = response.foods.first else { return nil }
        
        // Extract Macros (Values are per 100g in USDA)
        let protein = food.foodNutrients.first(where: { $0.nutrientId == PROTEIN_ID })?.value ?? 0
        let fat = food.foodNutrients.first(where: { $0.nutrientId == FAT_ID })?.value ?? 0
        let carbs = food.foodNutrients.first(where: { $0.nutrientId == CARBS_ID })?.value ?? 0
        let kcal = food.foodNutrients.first(where: { $0.nutrientId == KCAL_ID })?.value ?? 0
        
        return (protein, fat, carbs, kcal)
    }
}
