//
//  MealEntity+Extensions.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/1/26.
//
//  Computed properties and constants for the CoreData-generated
//  MealEntity and CachedMealEntity classes.
//

import CoreData
import Foundation

// MARK: - MealEntity

extension MealEntity {
  /// Calories computed from macros using Atwater factors: P*4 + C*4 + F*9.
  var totalCalories: Double {
    (totalProtein * 4) + (totalCarbs * 4) + (totalFat * 9)
  }

  /// Allowed portion unit strings displayed in pickers throughout the app.
  static let validUnits = ["", "g", "ml", "oz", "fl oz", "cups", "tbsp", "tsp", "piece", "slice"]
}

// MARK: - CachedMealEntity

extension CachedMealEntity {
  /// Calories computed from stored macros using Atwater factors.
  var calories: Double {
    (protein * 4) + (carbs * 4) + (fat * 9)
  }
}

// MARK: - Standalone Helper

/// Computes calories from individual macro values using Atwater factors.
func caloriesFromMacros(fat: Double, carbohydrates: Double, protein: Double) -> Double {
  (fat * 9) + (carbohydrates * 4) + (protein * 4)
}
