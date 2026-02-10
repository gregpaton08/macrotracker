//
//  EditCachedMealView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/30/26.
//

import SwiftUI

@MainActor
struct EditCachedMealView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) var viewContext
    
    var mealToEdit: CachedMealEntity?

    @State private var showSaveError = false
    @State private var name: String = ""
    @State private var portion: String = ""
    @State private var unit: String = "grams"
    
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    
    // 1. FOCUS STATE
    enum Field: Hashable {
        case name, portion, protein, carbs, fat
    }
    @FocusState private var focusedField: Field?
    
    var body: some View {
        Form {
            Section(header: Text("Details")) {
                TextField("Name (e.g. Banana)", text: $name)
                    .focused($focusedField, equals: .name) // 2. BIND FOCUS
                
                HStack {
                    TextField("Portion", text: $portion)
                        .focused($focusedField, equals: .portion) // 2. BIND FOCUS
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    Picker("Unit", selection: $unit) {
                        ForEach(MealEntity.validUnits, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                    .labelsHidden()
                }
            }
            
            Section(header: Text("Macros per Portion")) {
                
                HStack {
                    Text("Fat (g)")
                    Spacer()
                    TextField("0", text: $fat)
                        .focused($focusedField, equals: .fat) // 2. BIND FOCUS
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
                HStack {
                    Text("Carbs (g)")
                    Spacer()
                    TextField("0", text: $carbs)
                        .focused($focusedField, equals: .carbs) // 2. BIND FOCUS
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
                
                HStack {
                    Text("Protein (g)")
                    Spacer()
                    TextField("0", text: $protein)
                        .focused($focusedField, equals: .protein) // 2. BIND FOCUS
                        .multilineTextAlignment(.trailing)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                }
            }
        }
        .navigationTitle(mealToEdit == nil ? "New Saved Meal" : "Edit Meal")
        // 3. KEYBOARD TOOLBAR
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Save") { save() }
                    .disabled(name.isEmpty)
            }
            
            // The Keyboard Arrows
            ToolbarItemGroup(placement: .keyboard) {
                Button(action: { moveFocus(direction: -1) }) {
                    Image(systemName: "chevron.up")
                }
                .disabled(focusedField == .name)
                
                Button(action: { moveFocus(direction: 1) }) {
                    Image(systemName: "chevron.down")
                }
                .disabled(focusedField == .fat)
                
                Spacer()
                
                Button("Done") {
                    focusedField = nil
                }
            }
        }
        .alert("Save Failed", isPresented: $showSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Could not save changes. Please try again.")
        }
        .onAppear {
            if let meal = mealToEdit {
                name = meal.name ?? ""
                portion = meal.portionSize ?? ""
                unit = meal.unit ?? "grams"
                protein = String(format: "%.1f", meal.protein)
                carbs = String(format: "%.1f", meal.carbs)
                fat = String(format: "%.1f", meal.fat)
            }
        }
    }
    
    // 4. LOGIC
    private func moveFocus(direction: Int) {
        let order: [Field] = [.name, .portion, .protein, .carbs, .fat]
        
        guard let current = focusedField,
              let index = order.firstIndex(of: current) else { return }
        
        let nextIndex = index + direction
        if nextIndex >= 0 && nextIndex < order.count {
            focusedField = order[nextIndex]
        }
    }
    
    private func save() {
        let p = max(0, Double(protein) ?? 0)
        let c = max(0, Double(carbs) ?? 0)
        let f = max(0, Double(fat) ?? 0)
        
        if let meal = mealToEdit {
            meal.name = name
            meal.portionSize = portion
            meal.unit = unit
            meal.protein = p
            meal.carbs = c
            meal.fat = f
            // meal.calories = computedKcal (Only if column still exists)
        } else {
            MealCacheManager.shared.cacheMeal(
                name: name, p: p, f: f, c: c,
                portion: portion, unit: unit
            )
        }
        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            viewContext.rollback()
            showSaveError = true
        }
    }
}
