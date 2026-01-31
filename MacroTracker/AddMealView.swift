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
    
    let units = ["grams", "ounces", "cups", "slices", "pieces", "whole"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Food Details")) {
                    // Description Field with Autocomplete Logic
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("Description (e.g. Oatmeal)", text: $description)
                            .onChange(of: description) { newValue in
                                showSuggestions = !newValue.isEmpty
                            }
                        
                        // THE AUTOCOMPLETE DROPDOWN
                        if showSuggestions {
                            AutocompleteList(query: description) { selectedMeal in
                                // Auto-fill Logic
                                self.description = selectedMeal.name ?? ""
                                self.portionSize = selectedMeal.portionSize ?? ""
                                self.selectedUnit = selectedMeal.unit ?? "grams"
                                self.protein = String(format: "%.1f", selectedMeal.protein)
                                self.fat = String(format: "%.1f", selectedMeal.fat)
                                self.carbs = String(format: "%.1f", selectedMeal.carbs)
                                self.calories = String(format: "%.0f", selectedMeal.calories)
                                
                                // Hide suggestions and keyboard
                                self.showSuggestions = false
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("Portion", text: $portionSize)
                            .keyboardType(.decimalPad)
                        Picker("Unit", selection: $selectedUnit) {
                            ForEach(units, id: \.self) { unit in
                                Text(unit).tag(unit)
                            }
                        }
                        .labelsHidden()
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
                    HStack { Text("Calories"); Spacer(); TextField("0", text: $calories).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("Protein (g)"); Spacer(); TextField("0", text: $protein).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("Carbs (g)"); Spacer(); TextField("0", text: $carbs).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
                    HStack { Text("Fat (g)"); Spacer(); TextField("0", text: $fat).keyboardType(.decimalPad).multilineTextAlignment(.trailing) }
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
    
    private func performAutoFill() {
        let fullQuery = "\(portionSize) \(selectedUnit) \(description)"
        Task {
            if let result = await viewModel.calculateMacros(description: fullQuery) {
                calories = String(format: "%.0f", result.k)
                protein = String(format: "%.1f", result.p)
                carbs = String(format: "%.1f", result.c)
                fat = String(format: "%.1f", result.f)
            }
        }
    }
    
    private func saveMeal() {
        let p = Double(protein) ?? 0.0
        let c = Double(carbs) ?? 0.0
        let f = Double(fat) ?? 0.0
        let k = Double(calories) ?? 0.0
        let w = (Double(portionSize) ?? 0)
        
        // 1. Save to Core Data (Actual Log)
        viewModel.saveMeal(
            description: description,
            p: p, f: f, c: c, kcal: k,
            weight: w > 0 ? w : 100
        )
        
        // 2. Save to Cache (Learn this meal)
        MealCacheManager.shared.cacheMeal(
            name: description,
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
