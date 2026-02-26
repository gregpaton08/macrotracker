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
  let brands: String?
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
  func fetchProduct(barcode: String) async throws -> (
    name: String, sq: Double, squ: String, f: Double, c: Double, p: Double
  )? {
    logger.info("Looking up barcode: \(barcode)")

    let urlString = "https://world.openfoodfacts.org/api/v0/product/\(barcode).json"
    guard let url = URL(string: urlString) else {
      logger.error("Could not construct URL for barcode: \(barcode)")
      return nil
    }

    var request = URLRequest(url: url)
    // OFF requests a User-Agent to identify the app
    request.setValue("MacroTracker - iOS - Version 1.0", forHTTPHeaderField: "User-Agent")

    let (data, response) = try await session.data(for: request)

    if let http = response as? HTTPURLResponse {
      logger.debug("HTTP \(http.statusCode) for barcode \(barcode)")
    }

    let decoded = try JSONDecoder().decode(OpenFoodFactsResponse.self, from: data)

    guard let product = decoded.product else {
      logger.warning(
        "No product in response for barcode \(barcode) (status: \(decoded.status ?? -1))")
      return nil
    }

    guard let nuts = product.nutriments else {
      logger.warning(
        "Product '\(product.product_name ?? "unknown")' has no nutriments for barcode \(barcode)"
      )
      return nil
    }

    self.logger.debug("product = \(String(describing: nuts))")

    let name =
      if product.brands != nil { "\(product.brands ?? "") \(product.product_name ?? "")" } else {
        "Unknown Product"
      }

    let (sq, squ, f, c, p) =
      if nuts.fat_serving != nil, nuts.carbohydrates_serving != nil, nuts.proteins_serving != nil {
        (
          sq: product.serving_quantity ?? 0,
          squ: product.serving_quantity_unit ?? "", f: nuts.fat_serving!,
          c: nuts.carbohydrates_serving!, p: nuts.proteins_serving!
        )
      } else {
        (
          sq: 100, squ: "g", f: nuts.fat_100g ?? 0, c: nuts.carbohydrates_100g ?? 0,
          p: nuts.proteins_100g ?? 0
        )
      }

    return (
      name: name,
      sq: sq,
      squ: squ,
      f: f,
      c: c,
      p: p
    )
  }
}
