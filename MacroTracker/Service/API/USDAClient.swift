//
//  USDAClient.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/5/26.
//
//  HTTP client for the USDA Food Data Central API.
//  Searches for a food item and returns per-100 g macronutrient values
//  (protein, fat, carbs, calories) from the first matching result.
//

import Foundation
import OSLog

// MARK: - USDA Client

class USDAClient {
    /// Standard USDA nutrient IDs used to extract macro values from search results.
    private let PROTEIN_ID = 1003
    private let FAT_ID = 1004
    private let CARBS_ID = 1005
    private let KCAL_ID = 1008

    private let logger = Logger(subsystem: "com.macrotracker", category: "USDAClient")
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    /// Searches USDA FDC for `query` and returns per-100 g macros from the top result.
    ///
    /// Only Foundation and SR Legacy data types are searched (most reliable).
    /// Returns `nil` when no results match the query.
    func fetchNutrients(query: String) async throws -> (protein: Double, fat: Double, carbs: Double, kcal: Double)? {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.nal.usda.gov/fdc/v1/foods/search?query=\(encodedQuery)&dataType=Foundation,SR%20Legacy&pageSize=1&api_key=\(apiKey)"
        
        self.logger.debug("Searching USDA: \(query)")
        
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL, userInfo: [NSLocalizedDescriptionKey: "Invalid USDA search URL."])
        }
        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let message: String
            switch httpResponse.statusCode {
            case 401, 403: message = "Invalid USDA API key. Check Settings."
            case 429: message = "USDA rate limit reached. Try again shortly."
            default: message = "USDA request failed (HTTP \(httpResponse.statusCode))."
            }
            throw URLError(.badServerResponse, userInfo: [NSLocalizedDescriptionKey: message])
        }
        
        let searchResponse = try JSONDecoder().decode(USDAFoodSearchResponse.self, from: data)
        
        guard let foods = searchResponse.foods, let food = foods.first else {
            self.logger.warning("No results for \(query)")
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
