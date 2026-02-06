//
//  USDAClient.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/5/26.
//

import Foundation
import OSLog

// MARK: - USDA Client
class USDAClient {
    // Standard Nutrient IDs
    private let PROTEIN_ID = 1003
    private let FAT_ID = 1004
    private let CARBS_ID = 1005
    private let KCAL_ID = 1008
//    let logger: Logging.Logger
    private let logger = Logger(subsystem: "com.yourdomain.yourapp", category: "USDAClient")
    
    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }
//    init() {
//        var logger = parentLogger
//        logger[metadataKey: "class"] = "USDAClient"
//        logger.logLevel = .debug
//        self.logger = logger
//    }
    
    func fetchNutrients(query: String) async throws -> (protein: Double, fat: Double, carbs: Double, kcal: Double)? {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        let urlString = "https://api.nal.usda.gov/fdc/v1/foods/search?query=\(encodedQuery)&dataType=Foundation,SR%20Legacy&pageSize=1&api_key=\(apiKey)"
        
        self.logger.debug("Searching USDA: \(query)")
        
        guard let url = URL(string: urlString) else { return nil }
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else { return nil }
        
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
