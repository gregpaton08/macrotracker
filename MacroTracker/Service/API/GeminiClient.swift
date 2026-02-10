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
    private let logger = Logger(subsystem: "com.macrotracker", category: "GeminiClient")

    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
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
}
