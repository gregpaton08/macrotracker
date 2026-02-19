//
//  OpenFoodFactsClient.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/18/26.
//

import Foundation
import OSLog

struct OpenFoodFactsResponse: Codable {
    let product: Product?
    let status: Int?
}

struct Product: Codable {
    let product_name: String?
    let nutriments: Nutriments?
}

struct Nutriments: Codable {
    let energy_kcal_100g: Double?
    let proteins_100g: Double?
    let carbohydrates_100g: Double?
    let fat_100g: Double?
    
    // API sometimes uses different keys, but these are standard for OFF
    enum CodingKeys: String, CodingKey {
        case energy_kcal_100g = "energy-kcal_100g"
        case proteins_100g = "proteins_100g"
        case carbohydrates_100g = "carbohydrates_100g"
        case fat_100g = "fat_100g"
    }
}

class OpenFoodFactsClient {
    private let session = URLSession.shared
    private let logger = Logger(subsystem: "com.macrotracker", category: "OpenFoodFacts")
    
    func fetchProduct(barcode: String) async throws -> (name: String, p: Double, c: Double, f: Double, kcal: Double)? {
        let urlString = "https://world.openfoodfacts.org/api/v0/product/\(barcode).json"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        // OFF requests a User-Agent to identify the app
        request.setValue("MacroTracker - iOS - Version 1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await session.data(for: request)
        let decoded = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
        
        guard let product = decoded.product, let nuts = product.nutriments else { return nil }
        
        return (
            name: product.product_name ?? "Unknown Product",
            p: nuts.proteins_100g ?? 0,
            c: nuts.carbohydrates_100g ?? 0,
            f: nuts.fat_100g ?? 0,
            kcal: nuts.energy_kcal_100g ?? 0
        )
    }
}
