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
    
    // 1. Focus State
    enum Field: Hashable {
        case summary, fat, carbs, protein
    }
    @FocusState private var focusedField: Field?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Meal Info")) {
                    TextField("Summary", text: $summary)
                        .focused($focusedField, equals: .summary)
                    
                    DatePicker("Date & Time", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section(header: Text("Total Macros")) {
                    HStack {
                        Text("Fat")
                        Spacer()
                        TextField("0", text: $fat)
                            .focused($focusedField, equals: .fat)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Carbs")
                        Spacer()
                        TextField("0", text: $carbs)
                            .focused($focusedField, equals: .carbs)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Protein")
                        Spacer()
                        TextField("0", text: $protein)
                            .focused($focusedField, equals: .protein)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                Section {
                    Button("Save Changes") { saveChanges() }
                }
            }
            .navigationTitle("Edit Meal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { presentationMode.wrappedValue.dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") { saveChanges() }
                }
                
                // MARK: - KEYBOARD TOOLBAR
                ToolbarItemGroup(placement: .keyboard) {
                    Button(action: { moveFocus(direction: -1) }) {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(focusedField == .summary)
                    
                    Button(action: { moveFocus(direction: 1) }) {
                        Image(systemName: "chevron.down")
                    }
                    .disabled(focusedField == .protein)
                    
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .onAppear {
                summary = meal.summary ?? ""
                timestamp = meal.timestamp ?? Date()
                protein = String(format: "%.1f", meal.totalProtein)
                carbs = String(format: "%.1f", meal.totalCarbs)
                fat = String(format: "%.1f", meal.totalFat)
            }
        }
    }
    
    private func moveFocus(direction: Int) {
        let order: [Field] = [.summary, .fat, .carbs, .protein]
        guard let current = focusedField, let index = order.firstIndex(of: current) else { return }
        
        let nextIndex = index + direction
        if nextIndex >= 0 && nextIndex < order.count {
            focusedField = order[nextIndex]
        }
    }
    
    private func saveChanges() {
        meal.summary = summary
        meal.timestamp = timestamp
        meal.totalProtein = Double(protein) ?? 0
        meal.totalCarbs = Double(carbs) ?? 0
        meal.totalFat = Double(fat) ?? 0
        
        try? viewContext.save()
        presentationMode.wrappedValue.dismiss()
    }
}
