//
//  AddMealView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/30/26.
//

import SwiftUI
import CoreData

struct AddMealView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: MacroViewModel
    
    // MARK: - State
    
    // 1. Inputs
    @State private var description: String = ""
    @State private var portionSize: String = ""
    @State private var selectedUnit: String = "g"
    
    // 2. Macros (Fat -> Carbs -> Protein)
    @State private var fat: String = ""
    @State private var carbs: String = ""
    @State private var protein: String = ""
    
    // 3. Logic State
    @State private var activeCachedMeal: CachedMealEntity? = nil // The meal we are scaling off of
    @State private var isCalculating = false
    @FocusState private var focusedField: Field?
    
    // Units for Dropdown
    let units = ["g", "oz", "ml", "cups", "tbsp", "tsp", "pieces", "slice"]
    
    enum Field: Hashable {
        case description, portion, fat, carbs, protein
    }
    
    // MARK: - Autocomplete Fetcher
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CachedMealEntity.lastUsed, ascending: false)],
        animation: .default
    )
    private var cachedMeals: FetchedResults<CachedMealEntity>
    
    // Filter suggestions based on what user types
    var suggestions: [CachedMealEntity] {
        if description.isEmpty { return [] }
        return cachedMeals.filter {
            ($0.name ?? "").localizedCaseInsensitiveContains(description)
        }
    }

    var body: some View {
        NavigationView {
            Form {
                // MARK: - SECTION 1: FOOD DETAILS
                Section(header: Text("Food Details")) {
                    
                    
                    // Description & Autocomplete
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("Description (e.g. Chicken Breast)", text: $description)
                            .focused($focusedField, equals: .description)
                            .submitLabel(.next)
                            .onChange(of: description) { newValue in
                                // If user types something new, break the link to the cached meal
                                if let active = activeCachedMeal, active.name != newValue {
                                    // Optional: activeCachedMeal = nil
                                }
                            }
                        
                        // Autocomplete List
                        if !suggestions.isEmpty && focusedField == .description {
                            List {
                                ForEach(suggestions.prefix(3), id: \.self) { meal in
                                    Button(action: { applyCachedMeal(meal) }) {
                                        VStack(alignment: .leading) {
                                            Text(meal.name ?? "Unknown").foregroundColor(.primary)
                                            Text("Base: \(meal.portionSize ?? "100") \(meal.unit ?? "g") • P:\(Int(meal.protein))")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .frame(height: 120) // Limit height
                            .listStyle(.plain)
                        }
                    }
                    
                    // Portion & Unit Picker
                    HStack {
                        TextField("Portion", text: $portionSize)
                            .focused($focusedField, equals: .portion)
                            .keyboardType(.decimalPad)
                            .onChange(of: portionSize) { _ in recalculateMacros() }
                        
                        Picker("Unit", selection: $selectedUnit) {
                            ForEach(units, id: \.self) { unit in
                                Text(unit).tag(unit)
                            }
                        }
                        .labelsHidden()
                        .onChange(of: selectedUnit) { _ in recalculateMacros() }
                    }
                    
                    // AI Auto-Fill Button
                    Button(action: performAIAnalysis) {
                        HStack {
                            Image(systemName: "sparkles")
                            if isCalculating {
                                Text("Calculating...")
                            } else {
                                Text("Auto-Fill with AI")
                            }
                        }
                    }
                    .disabled(description.isEmpty || isCalculating)
                }
                
                // MARK: - SECTION 2: MACROS
                Section(header: Text("Macros (Auto-Scales)")) {
                    // FAT
                    HStack {
                        Text("Fat (g)")
                        Spacer()
                        TextField("0", text: $fat)
                            .focused($focusedField, equals: .fat)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    
                    // CARBS
                    HStack {
                        Text("Carbs (g)")
                        Spacer()
                        TextField("0", text: $carbs)
                            .focused($focusedField, equals: .carbs)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    
                    // PROTEIN
                    HStack {
                        Text("Protein (g)")
                        Spacer()
                        TextField("0", text: $protein)
                            .focused($focusedField, equals: .protein)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                }
                
                // MARK: - SAVE BUTTON
                Section {
                    Button("Save Meal") {
                        saveMeal()
                    }
                    .disabled(description.isEmpty)
                }
            }
            .navigationTitle("Add Meal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
        }
    }
    
    // MARK: - LOGIC
    
    // 1. Apply a selected suggestion
    private func applyCachedMeal(_ meal: CachedMealEntity) {
        // Link the meal
        self.activeCachedMeal = meal
        
        // Fill Text Fields
        self.description = meal.name ?? ""
        self.selectedUnit = meal.unit ?? "g"
        
        // Set Default Portion
        // If user already typed "200", keep "200". If empty, use saved portion.
        if portionSize.isEmpty {
            self.portionSize = meal.portionSize ?? "100"
        }
        
        // Trigger calc
        recalculateMacros()
        
        // Dismiss keyboard/list
        focusedField = nil
    }
    
    // 2. Scale Macros based on Portion
    private func recalculateMacros() {
        guard let cached = activeCachedMeal else { return }
        
        // Get numbers
        let currentSize = Double(portionSize) ?? 0
        let baseSize = Double(cached.portionSize ?? "0") ?? 0
        
        // Only scale if:
        // 1. We have valid numbers
        // 2. The units match (Scaling 100g base to 2oz requires conversion logic, simpler to require matching units for now)
        if currentSize > 0, baseSize > 0, cached.unit == selectedUnit {
            let ratio = currentSize / baseSize
            
            self.fat = String(format: "%.1f", cached.fat * ratio)
            self.carbs = String(format: "%.1f", cached.carbs * ratio)
            self.protein = String(format: "%.1f", cached.protein * ratio)
        } else {
            // Fallback to base values if no portion entered yet
            self.fat = String(format: "%.1f", cached.fat)
            self.carbs = String(format: "%.1f", cached.carbs)
            self.protein = String(format: "%.1f", cached.protein)
        }
    }
    
    // 3. AI Analysis
    private func performAIAnalysis() {
        guard !description.isEmpty else { return }
        isCalculating = true
        focusedField = nil
        
        Task {
            // Send "200 g Chicken" to AI
            let query = portionSize.isEmpty ? description : "\(portionSize) \(selectedUnit) \(description)"
            
            if let result = await viewModel.calculateMacros(description: query) {
                fat = String(format: "%.1f", result.f)
                carbs = String(format: "%.1f", result.c)
                protein = String(format: "%.1f", result.p)
                
                // Clear the cached link since AI just gave us fresh data
                activeCachedMeal = nil
            }
            isCalculating = false
        }
    }
    
    // 4. Save
    private func saveMeal() {
        let p = Double(protein) ?? 0
        let f = Double(fat) ?? 0
        let c = Double(carbs) ?? 0
        
        // Convert input portion to grams for standardizing the database
        // (Assuming ViewModel expects grams)
        let rawWeight = Double(portionSize) ?? 0
        let weightInGrams = convertToGrams(amount: rawWeight, unit: selectedUnit)
        
        viewModel.saveMeal(
            description: description,
            p: p,
            f: f,
            c: c,
            weight: weightInGrams
        )
        
        // Cache this meal for next time
        // Note: You need to make sure MealCacheManager exists,
        // OR add this logic to your ViewModel.
        saveToCache(p: p, f: f, c: c)
        
        presentationMode.wrappedValue.dismiss()
    }
    
    // Simple helper to save recent items
    private func saveToCache(p: Double, f: Double, c: Double) {
        // This is a quick inline CoreData save.
        // Ideally, move this to ViewModel.
        let cached = CachedMealEntity(context: viewModel.context)
        cached.name = description
        cached.protein = p
        cached.fat = f
        cached.carbs = c
        cached.portionSize = portionSize
        cached.unit = selectedUnit
        cached.lastUsed = Date()
        try? viewModel.context.save()
    }
    
    private func convertToGrams(amount: Double, unit: String) -> Double {
        switch unit {
        case "oz": return amount * 28.3495
        case "lbs": return amount * 453.592
        case "kg": return amount * 1000
        default: return amount // Assumes grams, ml, or pieces are 1:1 for simplicity
        }
    }
}
