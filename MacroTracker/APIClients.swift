//
//  APIClients.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/26/26.
//

import Foundation

import Logging

var parentLogger = Logging.Logger(label: "com.gregpaton08")

struct ApiResponse: Codable {
    let message: String
}

// MARK: - Gemini Client
class GeminiClient {
    private let session = URLSession.shared
    
    private let useDummyData = false
    let logger: Logging.Logger
    
    init() {
        var logger = parentLogger
        logger[metadataKey: "class"] = "GeminiClient"
        logger.logLevel = .debug
        self.logger = logger
    }
    
    // Recursive function with retry logic
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
        
        logger.debug("Parsing: '\(userText)'")
        
        let prompt = """
        Analyze this food description for earching the USDA database for macronutrients: "\(userText)".
        Complex foods should be broken down into a list of ingredients.
        Return ONLY valid JSON. Do not use Markdown formatting.
        Schema:
        { "items": [ { "search_term": "string (USDA database optimized)", "estimated_weight_grams": number } ] }
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
//        Logger.logResponse(data: data, response: response, error: nil, category: .gemini)
        
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode == 429 {
                self.logger.warning("Rate Limited.")
                return []
            }
            if httpResponse.statusCode != 200 {
                self.logger.error("Received HTTP response: \(httpResponse.statusCode)")
                
                do {
                    let decodedData = try JSONDecoder().decode(ApiResponse.self, from: data)
                    let userInfo: [String: Any] = [NSLocalizedDescriptionKey: decodedData.message]
                    throw URLError(.badServerResponse, userInfo: userInfo)
                } catch {
                    print("Failed to decode JSON body")
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
        
        guard let cleanData = jsonText.data(using: .utf8) else { throw URLError(.cannotParseResponse) }
        let result = try JSONDecoder().decode(ParsedFoodIntent.self, from: cleanData).items
        
        
        Logger.log("result: \(result)", category: .gemini)
        return result
    }
}

// MARK: - USDA Client
class USDAClient {
    // Standard Nutrient IDs
    private let PROTEIN_ID = 1003
    private let FAT_ID = 1004
    private let CARBS_ID = 1005
    private let KCAL_ID = 1008
    let logger: Logging.Logger
    
    init() {
        var logger = parentLogger
        logger[metadataKey: "class"] = "USDAClient"
        logger.logLevel = .debug
        self.logger = logger
    }
    
    func fetchNutrients(query: String, apiKey: String) async throws -> (protein: Double, fat: Double, carbs: Double, kcal: Double)? {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.nal.usda.gov/fdc/v1/foods/search?query=\(encodedQuery)&dataType=Foundation,SR%20Legacy&pageSize=1&api_key=\(apiKey)"
        
        self.logger.debug("Searching USDA: \(query)")
        
        guard let url = URL(string: urlString) else { return nil }
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
        
        let searchResponse = try JSONDecoder().decode(USDAFoodSearchResponse.self, from: data)
        
        guard let foods = searchResponse.foods, let food = foods.first else {
            Logger.log("No results for \(query)", category: .usda, level: .warn)
            return nil
        }
        
        let nutrients = food.foodNutrients ?? []
        let p = nutrients.first(where: { $0.nutrientId == PROTEIN_ID })?.value ?? 0
        let f = nutrients.first(where: { $0.nutrientId == FAT_ID })?.value ?? 0
        let c = nutrients.first(where: { $0.nutrientId == CARBS_ID })?.value ?? 0
        let k = nutrients.first(where: { $0.nutrientId == KCAL_ID })?.value ?? 0
        
        self.logger.debug("F/C/P : \(f)/\(c)/\(p)")
        
        return (p, f, c, k)
    }
}
