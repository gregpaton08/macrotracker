//
//  GeminiClient.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/5/26.
//

import Foundation
import OSLog

struct ApiResponse: Codable {
    let message: String
}

// MARK: - Gemini Client
class GeminiClient {
    private let session = URLSession.shared
    
    private let useDummyData = false
//    let logger: Logging.Logger
    private let logger = Logger(subsystem: "com.yourdomain.yourapp", category: "GeminiClient")
    
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    // Recursive function with retry logic
    func parseInput(userText: String) async throws -> [ParsedFoodIntent.ParsedItem] {
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
        
        logger.warning("Parsing: '\(userText)'")
        
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
        logger.warning("jsonText = \(jsonText)")
        
        guard let cleanData = jsonText.data(using: .utf8) else { throw URLError(.cannotParseResponse) }
        let result = try JSONDecoder().decode(ParsedFoodIntent.self, from: cleanData).items
        
        
        logger.warning("result: \(result)")
        return result
    }
}
