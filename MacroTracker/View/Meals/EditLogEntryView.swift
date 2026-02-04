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
    
    // The existing meal to edit
    @ObservedObject var meal: MealEntity
    
    @State private var summary: String = ""
    @State private var timestamp: Date = Date()
    
    // Editable Macros
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Meal Info")) {
                    TextField("Summary", text: $summary)
                    DatePicker("Date & Time", selection: $timestamp, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section(header: Text("Total Macros")) {
                    HStack { Text("Fat"); Spacer(); TextField("0", text: $fat)
#if os(iOS)
                            .keyboardType(.decimalPad)
#endif
                        .multilineTextAlignment(.trailing) }
                    HStack { Text("Carbs"); Spacer(); TextField("0", text: $carbs)
#if os(iOS)
                            .keyboardType(.decimalPad)
#endif
                        .multilineTextAlignment(.trailing) }
                    HStack { Text("Protein"); Spacer(); TextField("0", text: $protein)
#if os(iOS)
                            .keyboardType(.decimalPad)
#endif
                        .multilineTextAlignment(.trailing) }
                }
                
                Section {
                    Button("Save Changes") {
                        saveChanges()
                    }
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
            }
            .onAppear {
                // Load data
                summary = meal.summary ?? ""
                timestamp = meal.timestamp ?? Date()
                protein = String(format: "%.1f", meal.totalProtein)
                carbs = String(format: "%.1f", meal.totalCarbs)
                fat = String(format: "%.1f", meal.totalFat)
            }
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
