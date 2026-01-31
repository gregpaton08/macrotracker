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
    
    // Form Inputs
    @State private var description: String = ""
    @State private var portionSize: String = ""
    @State private var selectedUnit: String = "grams"
    
    // Macros
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var calories: String = ""
    
    // Autocomplete State
    @State private var showSuggestions = false
    
    // Internal State: Track which cached meal we are currently "linked" to
    @State private var activeCachedMeal: CachedMealEntity? = nil
    
    let units = ["grams", "ounces", "cups", "slices", "pieces", "whole", "ml", "tbsp", "tsp"]
    
    // MARK: - Smart Query Logic
    // This strips "130g" from "130g Banana" so autocomplete finds "Banana"
    var cleanQuery: String {
        if let result = LocalParser.parse(description), !result.foodName.isEmpty {
            return result.foodName
        }
        return description
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Food Details")) {
                    // 1. Portion & Unit
                    HStack {
                        TextField("Portion", text: $portionSize)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .onChange(of: portionSize) { _ in recalculateMacros() }
                        
                        Picker("Unit", selection: $selectedUnit) {
                            ForEach(units, id: \.self) { unit in
                                Text(unit).tag(unit)
                            }
                        }
                        .labelsHidden()
                        .onChange(of: selectedUnit) { _ in recalculateMacros() }
                    }
                    
                    // 2. Description (Smart Parsing + Autocomplete)
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("Description (e.g. 150g Chicken)", text: $description)
                            .onChange(of: description) { newValue in
                                showSuggestions = !newValue.isEmpty
                                attemptRealtimeParse(newValue)
                                
                                // Reset active link if text diverges significantly
                                if let active = activeCachedMeal, active.name != cleanQuery {
                                    // Optional: You could nullify activeCachedMeal here if strict
                                }
                            }
                        
                        // UPDATED: Use 'cleanQuery' instead of 'description'
                        if showSuggestions && !cleanQuery.isEmpty {
                            AutocompleteList(query: cleanQuery) { selectedMeal in
                                // 1. Set Link
                                self.activeCachedMeal = selectedMeal
                                
                                // 2. Apply Data
                                applyCachedMeal(selectedMeal)
                                
                                // 3. Cleanup UI
                                // Note: We only replace the NAME part if parsing succeeded
                                // This keeps "130g" in the text box if the user typed it
                                if let result = LocalParser.parse(description) {
                                    // Reconstruct "130g Banana" using the standardized name from cache
                                    // This fixes typos (e.g. "130g bnn" -> "130g Banana")
                                    let prefix = description.prefix(upTo: description.range(of: result.foodName)?.lowerBound ?? description.endIndex)
                                    self.description = "\(prefix)\(selectedMeal.name ?? "")"
                                } else {
                                    self.description = selectedMeal.name ?? ""
                                }
                                
                                self.showSuggestions = false
                                #if os(iOS)
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                #endif
                            }
                        }
                    }
                }
                
                Section {
                    Button(action: performAutoFill) {
                        HStack {
                            Label("Auto-Fill from AI", systemImage: "sparkles")
                            if viewModel.isLoading { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(description.isEmpty || viewModel.isLoading)
                }
                
                Section(header: Text("Macros (Editable)")) {
                    HStack { Text("Calories"); Spacer(); TextField("0", text: $calories)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .multilineTextAlignment(.trailing) }
                    HStack { Text("Protein (g)"); Spacer(); TextField("0", text: $protein)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .multilineTextAlignment(.trailing) }
                    HStack { Text("Carbs (g)"); Spacer(); TextField("0", text: $carbs)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .multilineTextAlignment(.trailing) }
                    HStack { Text("Fat (g)"); Spacer(); TextField("0", text: $fat)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .multilineTextAlignment(.trailing) }
                }
                
                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundColor(.red) }
                }
            }
            .navigationTitle("Add Meal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Meal") {
                        saveMeal()
                        presentationMode.wrappedValue.dismiss()
                    }
                    .disabled(description.isEmpty)
                }
            }
        }
    }
    
    // MARK: - Logic
    
    private func recalculateMacros() {
        guard let cached = activeCachedMeal else { return }
        applyCachedMeal(cached)
    }
    
    private func attemptRealtimeParse(_ text: String) {
        guard let result = LocalParser.parse(text) else { return }
        
        let newPortion = String(format: "%.0f", result.qty)
        if portionSize != newPortion {
            portionSize = newPortion
        }
        
        if let rawUnit = result.unit, let normalized = normalizeUnit(rawUnit) {
            selectedUnit = normalized
        }
    }
    
    private func applyCachedMeal(_ cached: CachedMealEntity) {
        let cachedPortion = Double(cached.portionSize ?? "0") ?? 0
        let currentPortion = Double(self.portionSize) ?? 0
        
        if currentPortion > 0, cachedPortion > 0, cached.unit == self.selectedUnit {
            let ratio = currentPortion / cachedPortion
            self.protein = String(format: "%.1f", cached.protein * ratio)
            self.fat = String(format: "%.1f", cached.fat * ratio)
            self.carbs = String(format: "%.1f", cached.carbs * ratio)
            self.calories = String(format: "%.0f", cached.calories * ratio)
        } else if self.portionSize.isEmpty {
            self.portionSize = cached.portionSize ?? ""
            self.selectedUnit = cached.unit ?? "grams"
            self.protein = String(format: "%.1f", cached.protein)
            self.fat = String(format: "%.1f", cached.fat)
            self.carbs = String(format: "%.1f", cached.carbs)
            self.calories = String(format: "%.0f", cached.calories)
        }
    }
    
    private func normalizeUnit(_ input: String) -> String? {
        let map: [String: String] = [
            "g": "grams", "gram": "grams", "grams": "grams",
            "oz": "ounces", "ounce": "ounces", "ounces": "ounces",
            "cup": "cups", "cups": "cups",
            "ml": "ml", "l": "l",
            "lb": "lbs", "lbs": "lbs",
            "tbsp": "tbsp", "tsp": "tsp"
        ]
        return map[input.lowercased()]
    }
    
    private func performAutoFill() {
        let fullQuery = "\(portionSize) \(selectedUnit) \(description)"
        Task {
            if let result = await viewModel.calculateMacros(description: fullQuery) {
                calories = String(format: "%.0f", result.k)
                protein = String(format: "%.1f", result.p)
                carbs = String(format: "%.1f", result.c)
                fat = String(format: "%.1f", result.f)
                self.activeCachedMeal = nil
            }
        }
    }
    
    private func saveMeal() {
        let p = Double(protein) ?? 0.0
        let c = Double(carbs) ?? 0.0
        let f = Double(fat) ?? 0.0
        let k = Double(calories) ?? 0.0
        let w = (Double(portionSize) ?? 0)
        
        var finalName = description
        if let result = LocalParser.parse(description) {
            finalName = result.foodName.capitalized
        }
        
        viewModel.saveMeal(
            description: finalName,
            p: p, f: f, c: c, kcal: k,
            weight: w > 0 ? w : 100
        )
        
        MealCacheManager.shared.cacheMeal(
            name: finalName,
            p: p, f: f, c: c, k: k,
            portion: portionSize,
            unit: selectedUnit
        )
    }
}

// Helper View for Search Results
struct AutocompleteList: View {
    var query: String
    var onSelect: (CachedMealEntity) -> Void
    
    @FetchRequest var matches: FetchedResults<CachedMealEntity>
    
    init(query: String, onSelect: @escaping (CachedMealEntity) -> Void) {
        self.query = query
        self.onSelect = onSelect
        // Fetch matching names, sorted by most recently used
        _matches = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \CachedMealEntity.lastUsed, ascending: false)],
            predicate: NSPredicate(format: "name BEGINSWITH[cd] %@", query),
            animation: .default
        )
    }
    
    var body: some View {
        if !matches.isEmpty {
            List {
                ForEach(matches.prefix(3), id: \.self) { meal in
                    Button(action: { onSelect(meal) }) {
                        VStack(alignment: .leading) {
                            Text(meal.name ?? "").font(.subheadline).bold()
                            Text("\(meal.portionSize ?? "") \(meal.unit ?? "") • \(Int(meal.calories)) kcal")
                                .font(.caption).foregroundColor(.gray)
                        }
                    }
                }
            }
            .frame(height: 150) // Limit height so it doesn't take over screen
            .listStyle(.plain)
        }
    }
}
