//
//  EditCachedMealView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/30/26.
//

import SwiftUI

struct EditCachedMealView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) var viewContext
    
    var mealToEdit: CachedMealEntity?
    
    @State private var name: String = ""
    @State private var portion: String = ""
    @State private var unit: String = "grams"
    
    // REMOVED: @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    
    let units = ["grams", "ounces", "cups", "slices", "pieces", "whole", "ml", "tbsp", "tsp"]
    
    var body: some View {
        Form {
            Section(header: Text("Details")) {
                TextField("Name (e.g. Banana)", text: $name)
                
                HStack {
                    TextField("Portion", text: $portion)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    Picker("Unit", selection: $unit) {
                        ForEach(units, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                    .labelsHidden()
                }
            }
            
            Section(header: Text("Macros per Portion")) {
                // REMOVED: MacroRow(label: "Calories", text: $calories)
                MacroRow(label: "Protein (g)", text: $protein)
                                MacroRow(label: "Fat (g)", text: $fat)
            }
        }
        .navigationTitle(mealToEdit == nil ? "New Saved Meal" : "Edit Meal")
        .toolbar {
            Button("Save") { save() }
                .disabled(name.isEmpty)
        }
        .onAppear {
            if let meal = mealToEdit {
                name = meal.name ?? ""
                portion = meal.portionSize ?? ""
                unit = meal.unit ?? "grams"
                // No need to load calories into a text field
                protein = String(format: "%.1f", meal.protein)
                carbs = String(format: "%.1f", meal.carbs)
                fat = String(format: "%.1f", meal.fat)
            }
        }
    }
    
    private func save() {
        let p = Double(protein) ?? 0
        let c = Double(carbs) ?? 0
        let f = Double(fat) ?? 0
        
        if let meal = mealToEdit {
            // Edit Mode
            meal.name = name
            meal.portionSize = portion
            meal.unit = unit
            meal.protein = p
            meal.carbs = c
            meal.fat = f
        } else {
            // Create Mode
            MealCacheManager.shared.cacheMeal(
                name: name,
                p: p, f: f, c: c,
//                k: computedKcal, // Pass the computed value
                portion: portion,
                unit: unit
            )
        }
        
        try? viewContext.save()
        presentationMode.wrappedValue.dismiss()
    }
}

// Helper for clean layout
struct MacroRow: View {
    let label: String
    @Binding var text: String
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: $text)
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
                .multilineTextAlignment(.trailing)
        }
    }
}
