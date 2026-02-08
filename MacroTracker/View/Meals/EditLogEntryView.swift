//
//  EditLogEntryView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/30/26.
//

import SwiftUI

struct EditLogEntryView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.managedObjectContext) var viewContext
    
    @ObservedObject var meal: MealEntity
    
    @State private var summary: String = ""
    @State private var timestamp: Date = Date()
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    
    // Portion Scaling
    @State private var portion: String = ""
    @State private var portionUnit: String = "g" // Default
    
    // Density Logic (Macros per 1 unit of portion)
    @State private var densityP: Double = 0
    @State private var densityC: Double = 0
    @State private var densityF: Double = 0
    
    enum Field: Hashable { case summary, portion, fat, carbs, protein }
    @FocusState private var focusedField: Field?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Meal Info")) {
                    TextField("Summary", text: $summary).focused($focusedField, equals: .summary)
                    DatePicker("Date", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section(header: Text("Portion (Scales Macros)")) {
                    HStack {
                        TextField("Amount", text: $portion)
                            .focused($focusedField, equals: .portion)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .onChange(of: portion) { _ in scaleMacros() }
                        
                        Picker("Unit", selection: $portionUnit) {
                            ForEach(MealEntity.validUnits, id: \.self) { Text($0).tag($0) }
                        }
                        .labelsHidden()
                        // If unit changes (e.g. oz -> g), we might need to handle conversion
                        // But for simplicity, we assume user is just correcting the label here.
                    }
                }
                
                Section(header: Text("Total Macros")) {
                    HStack { Text("Fat"); Spacer(); TextField("0", text: $fat).focused($focusedField, equals: .fat).keyboardType(.decimalPad) }
                    HStack { Text("Carbs"); Spacer(); TextField("0", text: $carbs).focused($focusedField, equals: .carbs).keyboardType(.decimalPad) }
                    HStack { Text("Protein"); Spacer(); TextField("0", text: $protein).focused($focusedField, equals: .protein).keyboardType(.decimalPad) }
                }
                
                Section { Button("Save Changes") { saveChanges() } }
            }
            .navigationTitle("Edit Meal")
            .toolbar {
                ToolbarItem(placement: .primaryAction) { Button("Save") { saveChanges() } }
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { presentationMode.wrappedValue.dismiss() } }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Button(action: { moveFocus(-1) }) { Image(systemName: "chevron.up") }
                    Button(action: { moveFocus(1) }) { Image(systemName: "chevron.down") }
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .onChange(of: focusedField) { newValue in
                guard newValue != nil else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)), to: nil, from: nil, for: nil)
                }
            }
            .onAppear(perform: loadData)
        }
    }
    
    // MARK: - LOGIC
    
    private func loadData() {
        summary = meal.summary ?? ""
        timestamp = meal.timestamp ?? Date()
        
        let p = meal.totalProtein
        let c = meal.totalCarbs
        let f = meal.totalFat
        
        protein = String(format: "%.1f", p)
        carbs = String(format: "%.1f", c)
        fat = String(format: "%.1f", f)
        
        // Load directly from MealEntity
        let storedPortion = meal.portion
        portion = String(format: "%.1f", storedPortion)
        portionUnit = meal.portionUnit ?? "g"
        
        // Calculate Density (Macro amount per 1 unit of portion)
        // e.g. if 2 slices = 20g protein, density = 10g/slice.
        if storedPortion > 0 {
            densityP = p / storedPortion
            densityC = c / storedPortion
            densityF = f / storedPortion
        }
    }
    
    private func scaleMacros() {
        let newPortion = Double(portion) ?? 0
        guard newPortion > 0 else { return }
        
        // Simple Scaling: NewAmount * Density
        // This works perfectly for "Slices", "Pieces", etc.
        // (Note: This assumes you aren't changing the Unit from "Slice" to "Grams" simultaneously)
        
        protein = String(format: "%.1f", newPortion * densityP)
        carbs = String(format: "%.1f", newPortion * densityC)
        fat = String(format: "%.1f", newPortion * densityF)
    }
    
    private func saveChanges() {
        meal.summary = summary
        meal.timestamp = timestamp
        meal.totalProtein = Double(protein) ?? 0
        meal.totalCarbs = Double(carbs) ?? 0
        meal.totalFat = Double(fat) ?? 0
        
        // Save new portion data
        meal.portion = Double(portion) ?? 0
        meal.portionUnit = portionUnit
        
        try? viewContext.save()
        presentationMode.wrappedValue.dismiss()
    }
    
    private func moveFocus(_ direction: Int) {
        let order: [Field] = [.summary, .portion, .fat, .carbs, .protein]
        guard let current = focusedField, let index = order.firstIndex(of: current) else { return }
        let next = index + direction
        if next >= 0 && next < order.count { focusedField = order[next] }
    }
}
