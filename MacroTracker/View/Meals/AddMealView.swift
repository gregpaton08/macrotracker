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
    @State private var description: String = ""
    @State private var portionSize: String = ""
    @State private var selectedUnit: String = "g"
    
    // Macros
    @State private var fat: String = ""
    @State private var carbs: String = ""
    @State private var protein: String = ""
    
    // Logic
    @State private var activeCachedMeal: CachedMealEntity? = nil
    @State private var isCalculating = false
    
    // 1. Focus State
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case description, portion, fat, carbs, protein
    }
    
    let units = ["g", "oz", "ml", "cups", "tbsp", "tsp", "pieces", "slice"]
    
    // Autocomplete...
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CachedMealEntity.lastUsed, ascending: false)],
        animation: .default
    )
    private var cachedMeals: FetchedResults<CachedMealEntity>
    
    var suggestions: [CachedMealEntity] {
        if description.isEmpty { return [] }
        return cachedMeals.filter {
            ($0.name ?? "").localizedCaseInsensitiveContains(description)
        }
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Food Details")) {
                    // Description
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("Description (e.g. Chicken Breast)", text: $description)
                            .focused($focusedField, equals: .description)
                            .submitLabel(.next)
                            .onChange(of: description) { newValue in
                                if let active = activeCachedMeal, active.name != newValue {
                                    // activeCachedMeal = nil // Optional
                                }
                            }
                        
                        // Suggestions List
                        if !suggestions.isEmpty && focusedField == .description {
                            List {
                                ForEach(suggestions.prefix(3), id: \.self) { meal in
                                    Button(action: { applyCachedMeal(meal) }) {
                                        VStack(alignment: .leading) {
                                            Text(meal.name ?? "Unknown").foregroundColor(.primary)
                                            Text("Base: \(meal.portionSize ?? "100") \(meal.unit ?? "g") • P:\(Int(meal.protein))")
                                                .font(.caption).foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                            .frame(height: 120)
                            .listStyle(.plain)
                        }
                    }
                    
                    // Portion
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
                    
                    // AI Button
                    Button(action: performAIAnalysis) {
                        HStack {
                            Image(systemName: "sparkles")
                            if isCalculating { Text("Calculating...") } else { Text("Auto-Fill with AI") }
                        }
                    }
                    .disabled(description.isEmpty || isCalculating)
                }
                
                Section(header: Text("Macros (Auto-Scales)")) {
                    HStack {
                        Text("Fat (g)"); Spacer()
                        TextField("0", text: $fat)
                            .focused($focusedField, equals: .fat)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("Carbs (g)"); Spacer()
                        TextField("0", text: $carbs)
                            .focused($focusedField, equals: .carbs)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("Protein (g)"); Spacer()
                        TextField("0", text: $protein)
                            .focused($focusedField, equals: .protein)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                    }
                }
                
                Section {
                    Button("Save Meal") { saveMeal() }
                        .disabled(description.isEmpty)
                }
            }
            .navigationTitle("Add Meal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                
                // MARK: - KEYBOARD NAVIGATION
                ToolbarItemGroup(placement: .keyboard) {
                    Button(action: { moveFocus(direction: -1) }) {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(focusedField == .description)
                    
                    Button(action: { moveFocus(direction: 1) }) {
                        Image(systemName: "chevron.down")
                    }
                    .disabled(focusedField == .protein)
                    
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
        }
    }
    
    // MARK: - Logic
    
    private func moveFocus(direction: Int) {
        let order: [Field] = [.description, .portion, .fat, .carbs, .protein]
        guard let current = focusedField, let index = order.firstIndex(of: current) else { return }
        let nextIndex = index + direction
        if nextIndex >= 0 && nextIndex < order.count {
            focusedField = order[nextIndex]
        }
    }
    
    // ... (Keep existing applyCachedMeal, recalculateMacros, performAIAnalysis, saveMeal logic) ...
    // Note: Ensure you copy the previous logic methods here (omitted for brevity)
    private func applyCachedMeal(_ meal: CachedMealEntity) {
        self.activeCachedMeal = meal
        self.description = meal.name ?? ""
        self.selectedUnit = meal.unit ?? "g"
        if portionSize.isEmpty { self.portionSize = meal.portionSize ?? "100" }
        recalculateMacros()
        focusedField = nil
    }
    
    private func recalculateMacros() {
        guard let cached = activeCachedMeal else { return }
        let currentSize = Double(portionSize) ?? 0
        let baseSize = Double(cached.portionSize ?? "0") ?? 0
        
        if currentSize > 0, baseSize > 0, cached.unit == selectedUnit {
            let ratio = currentSize / baseSize
            self.fat = String(format: "%.1f", cached.fat * ratio)
            self.carbs = String(format: "%.1f", cached.carbs * ratio)
            self.protein = String(format: "%.1f", cached.protein * ratio)
        } else {
            self.fat = String(format: "%.1f", cached.fat)
            self.carbs = String(format: "%.1f", cached.carbs)
            self.protein = String(format: "%.1f", cached.protein)
        }
    }
    
    private func performAIAnalysis() {
        guard !description.isEmpty else { return }
        isCalculating = true
        focusedField = nil
        Task {
            let query = portionSize.isEmpty ? description : "\(portionSize) \(selectedUnit) \(description)"
            if let result = await viewModel.calculateMacros(description: query) {
                fat = String(format: "%.1f", result.f)
                carbs = String(format: "%.1f", result.c)
                protein = String(format: "%.1f", result.p)
                activeCachedMeal = nil
            }
            isCalculating = false
        }
    }
    
    private func saveMeal() {
            let p = Double(protein) ?? 0
            let f = Double(fat) ?? 0
            let c = Double(carbs) ?? 0
            
            // "portionSize" is the text field string
            let amount = Double(portionSize) ?? 0
            
            viewModel.saveMeal(
                description: description,
                p: p, f: f, c: c,
                portion: amount,       // Pass as 'portion'
                portionUnit: selectedUnit // Pass 'portionUnit' (e.g. "slice")
            )
            
            // Cache Logic (Unchanged names in CacheManager for now, or update those too)
            MealCacheManager.shared.cacheMeal(
                name: description,
                p: p, f: f, c: c,
                portion: portionSize,
                unit: selectedUnit
            )
            
            presentationMode.wrappedValue.dismiss()
        }
}
