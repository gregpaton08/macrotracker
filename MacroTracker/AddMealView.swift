//
//  AddMealView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/30/26.
//

import SwiftUI

struct AddMealView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: MacroViewModel // Pass in the existing VM
    
    // Form Fields
    @State private var description: String = ""
    @State private var portionSize: String = ""
    @State private var selectedUnit: String = "grams"
    
    // Manual Macros
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var calories: String = ""
    
    let units = ["grams", "ounces", "cups", "slices", "pieces", "whole"]
    
    var body: some View {
        NavigationView {
            Form {
                // Section 1: Describe
                Section(header: Text("Food Details")) {
                    TextField("Description (e.g. Grilled Chicken)", text: $description)
                    
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
                
                // Section 2: Actions
                Section {
                    Button(action: performAutoFill) {
                        HStack {
                            Label("Auto-Fill from AI", systemImage: "sparkles")
                            if viewModel.isLoading {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(description.isEmpty || viewModel.isLoading)
                }
                
                // Section 3: The Data (Editable)
                Section(header: Text("Macros (Editable)")) {
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("0", text: $calories).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Protein (g)")
                        Spacer()
                        TextField("0", text: $protein).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Carbs (g)")
                        Spacer()
                        TextField("0", text: $carbs).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Fat (g)")
                        Spacer()
                        TextField("0", text: $fat).keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                }
                
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error).foregroundColor(.red)
                    }
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
                    .disabled(description.isEmpty) // Basic validation
                }
            }
        }
    }
    
    // Logic: Combine Description + Portion -> Send to AI -> Fill Fields
    private func performAutoFill() {
        // Construct a sentence like "200 grams grilled chicken"
        let fullQuery = "\(portionSize) \(selectedUnit) \(description)"
        
        Task {
            if let result = await viewModel.calculateMacros(description: fullQuery) {
                // Populate the UI fields (User can edit them after)
                calories = String(format: "%.0f", result.k)
                protein = String(format: "%.1f", result.p)
                carbs = String(format: "%.1f", result.c)
                fat = String(format: "%.1f", result.f)
            }
        }
    }
    
    private func saveMeal() {
        // Convert Strings back to Doubles
        let p = Double(protein) ?? 0.0
        let c = Double(carbs) ?? 0.0
        let f = Double(fat) ?? 0.0
        let k = Double(calories) ?? 0.0
        
        // Basic weight estimation if not provided by auto-fill
        let w = (Double(portionSize) ?? 0) // Simplified, usually you'd track the auto-filled weight
        
        viewModel.saveMeal(
            description: description,
            p: p, f: f, c: c, kcal: k,
            weight: w > 0 ? w : 100 // Default weight if manual entry
        )
    }
}
