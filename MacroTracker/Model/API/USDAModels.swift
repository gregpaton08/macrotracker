//
//  USDAModels.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/5/26.
//
//  Codable models for the USDA Food Data Central (FDC) search API.
//  All fields are optional for defensive decoding — the USDA API
//  occasionally returns nulls or error objects instead of food data.
//

import Foundation

// MARK: - USDA Search Response

/// Top-level response from `/fdc/v1/foods/search`.
struct USDAFoodSearchResponse: Codable {
    /// Optional to prevent crash if USDA returns an error object instead of a food list.
    let foods: [USDAFood]?
}

/// A single food item returned by USDA search.
struct USDAFood: Codable {
    let fdcId: Int?
    let description: String?
    let foodNutrients: [USDANutrient]?
}

/// A nutrient value within a food item. Keyed by `nutrientId`:
///   - 1003 = Protein
///   - 1004 = Fat
///   - 1005 = Carbohydrates
///   - 1008 = Calories (kcal)
struct USDANutrient: Codable {
    let nutrientId: Int?
    let value: Double?   // Sometimes null in the USDA database
}
