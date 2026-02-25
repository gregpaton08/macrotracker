//
//  MealDetailView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/29/26.
//
//  Read-only detail screen for a logged meal.
//  Shows date, time, portion, and full macro breakdown.
//  Provides Edit (sheet) and Delete (confirmation dialog) actions.
//

import CoreData
import SwiftUI

struct MealDetailView: View {
  @Environment(\.managedObjectContext) private var viewContext
  @Environment(\.dismiss) private var dismiss

  /// `@ObservedObject` so the view refreshes instantly after editing.
  @ObservedObject var meal: MealEntity
  @State private var isEditing = false
  @State private var showDeleteConfirmation = false

  var body: some View {
    List {
      Section(header: Text("Summary")) {
        HStack {
          Text("Date")
          Spacer()
          Text(meal.timestamp ?? Date(), style: .date)
        }
        HStack {
          Text("Time")
          Spacer()
          Text(meal.timestamp ?? Date(), style: .time)
        }
        HStack {
          Text("Portion")
          Spacer()
          // Display: "2.0 slice" or "150.0 g"
          Text("\(String(format: "%.1f", meal.portion)) \(meal.portionUnit ?? "")")
            .foregroundColor(.secondary)
        }
        HStack {
          Text("Calories").bold()
          Spacer()
          Text("\(Int(meal.totalCalories))")
        }
        HStack(spacing: 0) {
          Spacer()
          VStack(spacing: 2) {
            Text("Fat").font(.caption).foregroundColor(.secondary)
            Text("\(Int(meal.totalFat))g").bold()
          }
          Spacer()
          VStack(spacing: 2) {
            Text("Carbs").font(.caption).foregroundColor(.secondary)
            Text("\(Int(meal.totalCarbs))g").bold()
          }
          Spacer()
          VStack(spacing: 2) {
            Text("Protein").font(.caption).foregroundColor(.secondary)
            Text("\(Int(meal.totalProtein))g").bold()
          }
          Spacer()
        }
        .padding(.vertical, 4)
      }

      Section {
        Button(role: .destructive) {
          showDeleteConfirmation = true
        } label: {
          HStack {
            Spacer()
            Label("Delete Meal", systemImage: "trash")
            Spacer()
          }
        }
      }
    }
    .navigationTitle(meal.summary ?? "Meal")
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Edit") {
          isEditing = true
        }
      }
    }
    .sheet(isPresented: $isEditing) {
      EditLogEntryView(meal: meal)
    }
    .confirmationDialog(
      "Delete this meal?", isPresented: $showDeleteConfirmation, titleVisibility: .visible
    ) {
      Button("Delete", role: .destructive) {
        viewContext.delete(meal)
        try? viewContext.save()
        dismiss()
      }
    }
  }
}
