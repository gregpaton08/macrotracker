//
//  MealDetailView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/29/26.
//

import SwiftUI
import CoreData

struct MealDetailView: View {
    // Make meal ObservedObject so the view updates instantly when you edit it
    @ObservedObject var meal: MealEntity
    @State private var isEditing = false
    
    var ingredients: [FoodEntity] {
        let set = meal.ingredients as? Set<FoodEntity> ?? []
        return set.sorted { $0.name ?? "" < $1.name ?? "" }
    }
    
    var body: some View {
        List {
            Section(header: Text("Summary")) {
                HStack {
                    Text("Date")
                    Spacer()
                    Text(meal.timestamp ?? Date(), style: .date)
                }
                HStack {
                    Text("Time")
                    Spacer()
                    Text(meal.timestamp ?? Date(), style: .time)
                }
                HStack {
                    Text("Calories").bold()
                    Spacer()
                    Text("\(Int(meal.totalCalories))")
                }
                HStack {
                    Text("Fat")
                    Spacer()
                    Text("\(Int(meal.totalFat))g")
                }
                HStack {
                    Text("Carbs")
                    Spacer()
                    Text("\(Int(meal.totalCarbs))g")
                }
                HStack {
                    Text("Protein")
                    Spacer()
                    Text("\(Int(meal.totalProtein))g")
                }
            }
            
            Section(header: Text("Ingredients")) {
                if ingredients.isEmpty {
                    Text("No individual ingredients listed.")
                        .foregroundColor(.gray)
                } else {
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
        }
        .navigationTitle(meal.summary ?? "Meal")
        // ADD EDIT BUTTON HERE
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    isEditing = true
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditLogEntryView(meal: meal)
        }
    }
}
