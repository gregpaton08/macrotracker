//
//  USDAModels.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/5/26.
//

import Foundation

// MARK: - USDA API Response (Defensive Version)
struct USDAFoodSearchResponse: Codable {
    // OPTIONAL: Prevents crash if USDA returns an error object instead of food list
    let foods: [USDAFood]?
}

struct USDAFood: Codable {
    let fdcId: Int?
    let description: String?
    let foodNutrients: [USDANutrient]?
}

struct USDANutrient: Codable {
    let nutrientId: Int?
    let value: Double? // OPTIONAL: Sometimes null in USDA database
}
