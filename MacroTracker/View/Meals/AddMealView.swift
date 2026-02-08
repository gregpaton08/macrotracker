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
    
    // External Date Logic
    var targetDate: Date
    
    // Inputs
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
    
    // Focus
    @FocusState private var focusedField: Field?
    enum Field: Hashable {
        case description, portion, fat, carbs, protein
    }
    
    // Autocomplete
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
                // MARK: - SECTION 1: FOOD DETAILS
                Section(header: Text("Food Details")) {
                    // Description
                    VStack(alignment: .leading, spacing: 0) {
                        TextField("Description (e.g. Chicken)", text: $description)
                            .focused($focusedField, equals: .description)
                            .submitLabel(.next)
                            .onChange(of: description) { newValue in
                                if let active = activeCachedMeal, active.name != newValue {
                                    // activeCachedMeal = nil
                                }
                            }
                        
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
                    
                    // Portion & Unit
                    HStack {
                        TextField("Portion", text: $portionSize)
                            .focused($focusedField, equals: .portion)
                            .keyboardType(.decimalPad)
                            .onChange(of: portionSize) { _ in recalculateMacros() }
                        
                        Picker("Unit", selection: $selectedUnit) {
                            ForEach(MealEntity.validUnits, id: \.self) { unit in
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
                
                // MARK: - SECTION 2: MACROS (Compact Row)
                Section(header: Text("Macros (Auto-Scales)")) {
                    HStack(spacing: 20) {
                        // FAT
                        VStack(alignment: .center, spacing: 4) {
                            Text("Fat").font(.caption).bold().foregroundColor(.red)
                            TextField("0", text: $fat)
                                .focused($focusedField, equals: .fat)
                                .multilineTextAlignment(.center)
                                .keyboardType(.decimalPad)
                                .padding(8)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                        
                        // CARBS
                        VStack(alignment: .center, spacing: 4) {
                            Text("Carbs").font(.caption).bold().foregroundColor(.blue)
                            TextField("0", text: $carbs)
                                .focused($focusedField, equals: .carbs)
                                .multilineTextAlignment(.center)
                                .keyboardType(.decimalPad)
                                .padding(8)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                        
                        // PROTEIN
                        VStack(alignment: .center, spacing: 4) {
                            Text("Protein").font(.caption).bold().foregroundColor(.green)
                            TextField("0", text: $protein)
                                .focused($focusedField, equals: .protein)
                                .multilineTextAlignment(.center)
                                .keyboardType(.decimalPad)
                                .padding(8)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Bottom Save Button (Optional but convenient)
                Section {
                    Button("Save Meal") { saveMeal() }
                        .disabled(description.isEmpty)
                }
            }
            .navigationTitle("Add Meal")
            .toolbar {
                // Cancel (Left)
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                
                // MARK: - THE NEW SAVE BUTTON (Right)
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveMeal() }
                        .disabled(description.isEmpty)
                        .bold()
                }
                
                // Keyboard Toolbar (Arrows)
                ToolbarItemGroup(placement: .keyboard) {
                    Button(action: { moveFocus(-1) }) { Image(systemName: "chevron.up") }
                        .disabled(focusedField == .description)
                    Button(action: { moveFocus(1) }) { Image(systemName: "chevron.down") }
                        .disabled(focusedField == .protein)
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            // Auto-Select Text Logic
            .onChange(of: focusedField) { newValue in
                guard newValue != nil else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
                }
            }
        }
    }
    
    // MARK: - Logic
    
    private func moveFocus(_ direction: Int) {
        let order: [Field] = [.description, .portion, .fat, .carbs, .protein]
        guard let current = focusedField, let index = order.firstIndex(of: current) else { return }
        let next = index + direction
        if next >= 0 && next < order.count { focusedField = order[next] }
    }
    
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
        let amount = Double(portionSize) ?? 0
        
        viewModel.saveMeal(
            description: description,
            p: p, f: f, c: c,
            portion: amount,
            portionUnit: selectedUnit,
            date: targetDate
        )
        
        MealCacheManager.shared.cacheMeal(
            name: description, p: p, f: f, c: c, portion: portionSize, unit: selectedUnit
        )
        
        presentationMode.wrappedValue.dismiss()
    }
}
