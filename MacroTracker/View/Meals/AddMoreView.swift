//
//  AddMoreView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 3/12/26.
//
//  Sheet for scaling a logged meal's portion up (or down).
//  Shows the current portion, an "add" increment field, and a "total"
//  field — editing either one keeps both in sync. Saving scales all
//  macros proportionally to the new total portion.
//

import CoreData
import SwiftUI

struct AddMoreView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var meal: MealEntity

    // Snapshot captured at sheet open — used for proportional scaling.
    private let originalPortion: Double
    private let originalFat: Double
    private let originalCarbs: Double
    private let originalProtein: Double
    private let unit: String

    @State private var addText: String = "0"
    @State private var totalText: String
    @FocusState private var focused: Field?
    private enum Field { case add, total }

    init(meal: MealEntity) {
        self.meal = meal
        originalPortion = meal.portion
        originalFat = meal.totalFat
        originalCarbs = meal.totalCarbs
        originalProtein = meal.totalProtein
        unit = meal.portionUnit ?? ""
        _totalText = State(initialValue: AddMoreView.fmt(meal.portion))
    }

    // MARK: - Derived Values

    private var totalValue: Double { Double(totalText) ?? originalPortion }
    private var scale: Double {
        guard originalPortion > 0 else { return 1 }
        return totalValue / originalPortion
    }
    private var newFat: Double { originalFat     * scale }
    private var newCarbs: Double { originalCarbs   * scale }
    private var newProtein: Double { originalProtein * scale }
    private var newCalories: Double {
        caloriesFromMacros(fat: newFat, carbohydrates: newCarbs, protein: newProtein)
    }
    private var canSave: Bool { totalValue > 0 && originalPortion > 0 }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Form {
                // Current portion — read only
                Section {
                    LabeledContent("Current") {
                        Text(originalPortion > 0
                             ? "\(AddMoreView.fmt(originalPortion))\(unit.isEmpty ? "" : " \(unit)")"
                             : "—")
                            .foregroundColor(.secondary)
                    }
                }

                // Add / Total fields
                Section {
                    HStack {
                        Text("Add")
                        Spacer()
                        TextField("0", text: $addText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focused, equals: .add)
                            .frame(maxWidth: 120)
                            .onChange(of: addText) { _ in
                                guard focused == .add else { return }
                                let add = Double(addText) ?? 0
                                totalText = AddMoreView.fmt(originalPortion + add)
                            }
                        if !unit.isEmpty {
                            Text(unit).foregroundColor(.secondary)
                        }
                    }

                    HStack {
                        Text("Total")
                        Spacer()
                        TextField(AddMoreView.fmt(originalPortion), text: $totalText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focused, equals: .total)
                            .frame(maxWidth: 120)
                            .onChange(of: totalText) { _ in
                                guard focused == .total else { return }
                                let add = (Double(totalText) ?? originalPortion) - originalPortion
                                addText = AddMoreView.fmt(add)
                            }
                        if !unit.isEmpty {
                            Text(unit).foregroundColor(.secondary)
                        }
                    }
                } footer: {
                    if originalPortion <= 0 {
                        Text("No portion size is recorded for this meal — edit it first to enable scaling.")
                    }
                }

                // Live macro preview
                Section(header: Text("Updated Macros")) {
                    HStack {
                        Text("Calories").bold()
                        Spacer()
                        Text("\(Int(newCalories)) kcal")
                    }
                    HStack(spacing: 0) {
                        Spacer()
                        macroCol("Fat", value: newFat)
                        Spacer()
                        macroCol("Carbs", value: newCarbs)
                        Spacer()
                        macroCol("Protein", value: newProtein)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Add More")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Helpers

    private func save() {
        guard canSave else { return }
        meal.portion    = totalValue
        meal.totalFat   = originalFat     * scale
        meal.totalCarbs = originalCarbs   * scale
        meal.totalProtein = originalProtein * scale
        try? viewContext.save()
        dismiss()
    }

    private func macroCol(_ label: String, value: Double) -> some View {
        VStack(spacing: 2) {
            Text(label).font(.caption).foregroundColor(.secondary)
            Text("\(Int(value))g").bold()
        }
    }

    /// Formats a number without a trailing ".0" for whole numbers.
    private static func fmt(_ n: Double) -> String {
        n.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(n))
            : String(format: "%.1f", n)
    }
}
