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
                            Text("Portion")
                            Spacer()
                            // Display: "2.0 slice" or "150.0 g"
                            Text("\(String(format: "%.1f", meal.portion)) \(meal.portionUnit ?? "")")
                                .foregroundColor(.secondary)
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
