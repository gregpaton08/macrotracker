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
    @Environment(\.managedObjectContext) var viewContext
    @ObservedObject var viewModel: MacroViewModel
    
    // Inputs
    @State private var description: String = ""
    @State private var weight: String = ""
    
    // Macros (Fat -> Carbs -> Protein)
    @State private var fat: String = ""
    @State private var carbs: String = ""
    @State private var protein: String = ""
    
    // UX State
    @State private var isCalculating = false
    
    // Focus State
    enum Field: Hashable {
        case description, weight, fat, carbs, protein
    }
    @FocusState private var focusedField: Field?
    
    // Fetch Saved Meals for Autocomplete
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CachedMealEntity.name, ascending: true)],
        animation: .default
    )
    private var cachedMeals: FetchedResults<CachedMealEntity>
    
    // Filter logic for Autocomplete
    var suggestions: [CachedMealEntity] {
        if description.isEmpty { return [] }
        return cachedMeals.filter {
            ($0.name ?? "").localizedCaseInsensitiveContains(description)
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                // MARK: - SECTION 1: DETAILS & AI
                Section(header: Text("Meal Details")) {
                    // 1. Description Field
                    TextField("Description (e.g. Banana)", text: $description)
                        .focused($focusedField, equals: .description)
                        .submitLabel(.next)
                    
                    // 2. Autocomplete List (Only shows when typing matches)
                    if !suggestions.isEmpty && focusedField == .description {
                        ForEach(suggestions.prefix(3), id: \.self) { meal in
                            Button(action: { applySuggestion(meal) }) {
                                VStack(alignment: .leading) {
                                    Text(meal.name ?? "Unknown").foregroundColor(.primary)
                                    Text("F: \(Int(meal.fat)) C: \(Int(meal.carbs)) P: \(Int(meal.protein))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    // 3. Weight Field
                    TextField("Weight (g)", text: $weight)
                        .focused($focusedField, equals: .weight)
                        .keyboardType(.decimalPad)
                    
                    // 4. AI Button
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
                
                // MARK: - SECTION 2: MACROS (F -> C -> P)
                Section(header: Text("Macros")) {
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
                
                // Keyboard Navigation Arrows
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
    
    // MARK: - LOGIC
    
    private func applySuggestion(_ meal: CachedMealEntity) {
        // Auto-fill fields from the saved meal
        description = meal.name ?? description
        
        // If the saved meal has a "standard" portion size, you could pre-fill weight here if you tracked it
        // weight = meal.portionSize ?? ""
        
        fat = String(format: "%.1f", meal.fat)
        carbs = String(format: "%.1f", meal.carbs)
        protein = String(format: "%.1f", meal.protein)
        
        // Move focus to weight so user can adjust quantity if needed
        focusedField = .weight
    }
    
    private func performAIAnalysis() {
        guard !description.isEmpty else { return }
        isCalculating = true
        
        // Hide keyboard to show the user something is happening
        focusedField = nil
        
        Task {
            // Construct query (e.g. "150g Chicken Breast")
            let query = weight.isEmpty ? description : "\(weight)g \(description)"
            
            // Call ViewModel
            if let result = await viewModel.calculateMacros(description: query) {
                // Update UI on Main Thread
                fat = String(format: "%.1f", result.f)
                carbs = String(format: "%.1f", result.c)
                protein = String(format: "%.1f", result.p)
            }
            isCalculating = false
        }
    }
    
    private func saveMeal() {
        let w = Double(weight) ?? 0
        let f = Double(fat) ?? 0
        let c = Double(carbs) ?? 0
        let p = Double(protein) ?? 0
        
        viewModel.saveMeal(
            description: description,
            p: p,
            f: f,
            c: c,
            weight: w
        )
        
        presentationMode.wrappedValue.dismiss()
    }
    
    private func moveFocus(direction: Int) {
        let order: [Field] = [.description, .weight, .fat, .carbs, .protein]
        guard let current = focusedField, let index = order.firstIndex(of: current) else { return }
        let nextIndex = index + direction
        if nextIndex >= 0 && nextIndex < order.count {
            focusedField = order[nextIndex]
        }
    }
}
