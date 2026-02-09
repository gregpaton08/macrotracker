//
//  MealEntity+Extensions.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/1/26.
//

import Foundation
import CoreData

extension MealEntity {
    // This looks like a variable to the rest of your app,
    // but it calculates itself every time it is accessed.
    var totalCalories: Double {
        let p = self.totalProtein
        let c = self.totalCarbs
        let f = self.totalFat
        
        return (p * 4) + (c * 4) + (f * 9)
    }
    
    static let validUnits = ["", "g", "ml", "oz", "fl oz", "cups", "tbsp", "tsp", "piece", "slice"]
}

extension CachedMealEntity {
    var calories: Double {
        let p = self.protein
        let c = self.carbs
        let f = self.fat
        
        return (p * 4) + (c * 4) + (f * 9)
    }
}

func caloriesFromMacros(fat: Double, carbohydrates: Double, protein: Double) -> Double {
    return (fat * 9) + (carbohydrates * 4) + (protein * 4)
}
