//
//  OpenFoodFactsClient.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/18/26.
//
//  HTTP client for the Open Food Facts API.
//  Looks up a product by barcode and returns per-serving macros.
//  No API key required — only a descriptive User-Agent header.
//

import Foundation
import OSLog

// MARK: - Response Models

/// Top-level wrapper for the Open Food Facts product endpoint.
struct OpenFoodFactsResponse: Codable {
    let product: Product?
    let status: Int?
}

/// A single product record from Open Food Facts.
struct Product: Codable {
    let product_name: String?
    let nutriments: Nutriments?
    let serving_quantity: Double?
    let serving_quantity_unit: String?
}

/// Nutrient values from Open Food Facts. Per-serving values are preferred
/// over per-100 g because barcode scans typically represent a single serving.
struct Nutriments: Codable {
    let energy_kcal_100g: Double?
    let proteins_100g: Double?
    let carbohydrates_100g: Double?
    let fat_100g: Double?
    let fat_serving: Double?
    let carbohydrates_serving: Double?
    let proteins_serving: Double?

    enum CodingKeys: String, CodingKey {
        case energy_kcal_100g = "energy-kcal_100g"
        case proteins_100g = "proteins_100g"
        case carbohydrates_100g = "carbohydrates_100g"
        case fat_100g = "fat_100g"
        case fat_serving = "fat_serving"
        case carbohydrates_serving = "carbohydrates_serving"
        case proteins_serving = "proteins_serving"
    }
}

// MARK: - Client

class OpenFoodFactsClient {
    private let session = URLSession.shared
    private let logger = Logger(subsystem: "com.macrotracker", category: "OpenFoodFacts")

    /// Fetches a product by barcode and returns per-serving macro values.
    /// Returns `nil` if the barcode is not found or nutriment data is missing.
    func fetchProduct(barcode: String) async throws -> (name: String, sq: Double, squ: String, f: Double, c: Double, p: Double)? {
        let urlString = "https://world.openfoodfacts.org/api/v0/product/\(barcode).json"
        guard let url = URL(string: urlString) else { return nil }
        
        var request = URLRequest(url: url)
        // OFF requests a User-Agent to identify the app
        request.setValue("MacroTracker - iOS - Version 1.0", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await session.data(for: request)
        let decoded = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)
        
        guard let product = decoded.product, let nuts = product.nutriments else { return nil }
        
        self.logger.debug("product = \(String(describing: nuts))")
        
        return (
            name: product.product_name ?? "Unknown Product",
            sq: product.serving_quantity ?? 0,
            squ: product.serving_quantity_unit ?? "",
            f: nuts.fat_serving ?? 0,
            c: nuts.carbohydrates_serving ?? 0,
            p: nuts.proteins_serving ?? 0
        )
    }
}
