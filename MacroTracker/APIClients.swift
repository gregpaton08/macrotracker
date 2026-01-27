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
    
    private let useDummyData = false
    
    func parseInput(userText: String, apiKey: String) async throws -> [ParsedFoodIntent.ParsedItem] {
        if useDummyData {
            return [
                ParsedFoodIntent.ParsedItem(search_term: "honey", estimated_weight_grams: 61.0),
//                ParsedFoodIntent.ParsedItem(search_term: "avocado", estimated_weight_grams: 150.0),
//                ParsedFoodIntent.ParsedItem(search_term: "sourdough bread", estimated_weight_grams: 40.0)
            ]
        }
//        let model = "gemini-pro-latest"
//        let model = "gemini-2.0-flash"
        let model = "gemini-3-flash-preview"
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
            guard let url = URL(string: urlString) else { throw URLError(.badURL) }
            
            // Prompt Engineering: Explicitly tell it NOT to use Markdown, but we will clean it anyway
            let prompt = """
            Analyze this food log: "\(userText)".
            Return ONLY valid JSON. Do not use Markdown formatting.
            Schema:
            {
              "items": [
                {
                  "search_term": "string (USDA database optimized)",
                  "estimated_weight_grams": number
                }
              ]
            }
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
            
            // 1. Debugging: Check HTTP Status
            if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                 let errorText = String(data: data, encoding: .utf8) ?? "No error text"
                 print("🛑 Gemini API Error: \(httpResponse.statusCode) - \(errorText)")
                 throw URLError(.badServerResponse)
            }
            
            // 2. Decode the Outer Wrapper
            let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)
            
            guard var jsonText = geminiResponse.candidates?.first?.content.parts.first?.text else {
                throw URLError(.cannotParseResponse)
            }
            
            // 3. THE FIX: Strip Markdown Backticks
            // Gemini often returns: ```json \n { ... } \n ```
            if jsonText.contains("```") {
                jsonText = jsonText.replacingOccurrences(of: "```json", with: "")
                jsonText = jsonText.replacingOccurrences(of: "```", with: "")
            }
            
            // 4. Debugging: Print exactly what we are trying to decode
            print("🤖 Cleaned JSON from AI: \(jsonText)")
            
            guard let cleanData = jsonText.data(using: .utf8) else {
                throw URLError(.cannotParseResponse)
            }
            
            // 5. Decode the actual data
            let result = try JSONDecoder().decode(ParsedFoodIntent.self, from: cleanData)
            return result.items
        }
}

// MARK: - USDA Client
class USDAClient {
    // Standard Nutrient IDs
    private let PROTEIN_ID = 1003
    private let FAT_ID = 1004
    private let CARBS_ID = 1005
    private let KCAL_ID = 1008
    
    func fetchNutrients(query: String, apiKey: String) async throws -> (protein: Double, fat: Double, carbs: Double, kcal: Double)? {
        // Query for Foundation or SR Legacy foods for best data accuracy
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        print("encodedQuery = \(encodedQuery)")
        let urlString = "https://api.nal.usda.gov/fdc/v1/foods/search?query=\(encodedQuery)&dataType=Foundation,SR%20Legacy&pageSize=1&api_key=\(apiKey)"
        
        guard let url = URL(string: urlString) else { return nil }
        
        let (data, _) = try await URLSession.shared.data(from: url)
        // TODO: add error reporting and handling
//        print("fetchNutrients data = \(data)")
        if let stringResult = String(data: data, encoding: .utf8) {
            // Print the resulting string
//            print(stringResult)
        } else {
            print("Could not convert data to a UTF-8 string")
        }
        let response = try JSONDecoder().decode(USDAFoodSearchResponse.self, from: data)
        //        print("fetchNutrients response = \(response)")
        print("fetchNutrients response.foods = \(response.foods)")
        
        guard let food = response.foods.first else { return nil }
        print("fetchNutrients food = \(food)")
        
        // Extract Macros (Values are per 100g in USDA)
        let protein = food.foodNutrients.first(where: { $0.nutrientId == PROTEIN_ID })?.value ?? 0
        let fat = food.foodNutrients.first(where: { $0.nutrientId == FAT_ID })?.value ?? 0
        let carbs = food.foodNutrients.first(where: { $0.nutrientId == CARBS_ID })?.value ?? 0
        let kcal = food.foodNutrients.first(where: { $0.nutrientId == KCAL_ID })?.value ?? 0
        
        return (protein, fat, carbs, kcal)
    }
}
