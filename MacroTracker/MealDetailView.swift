//
//  MealDetailView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/29/26.
//

import SwiftUI
import CoreData

struct MealDetailView: View {
    let meal: MealEntity
    
    var ingredients: [FoodEntity] {
        // Convert NSSet to sorted Array
        let set = meal.ingredients as? Set<FoodEntity> ?? []
        return set.sorted { $0.name ?? "" < $1.name ?? "" }
    }
    
    var body: some View {
        List {
            Section(header: Text("Summary")) {
                HStack {
                    Text("Calories").bold()
                    Spacer()
                    Text("\(Int(meal.totalCalories))")
                }
                HStack {
                    Text("Protein")
                    Spacer()
                    Text("\(Int(meal.totalProtein))g")
                }
                HStack {
                    Text("Carbs")
                    Spacer()
                    Text("\(Int(meal.totalCarbs))g")
                }
                HStack {
                    Text("Fat")
                    Spacer()
                    Text("\(Int(meal.totalFat))g")
                }
            }
            
            Section(header: Text("Ingredients")) {
                ForEach(ingredients) { food in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(food.name ?? "Unknown")
                            Text("\(Int(food.weightGrams))g").font(.caption).foregroundColor(.gray)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            Text("\(Int(food.calories)) kcal").font(.caption).bold()
                            Text("P:\(Int(food.protein)) C:\(Int(food.carbs)) F:\(Int(food.fat))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle(meal.summary ?? "Meal")
    }
}
