//
//  TrackerView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/28/26.
//
// This is the main view where you enter in food you ate and it shows a history of food items.

import SwiftUI
import CoreData

import SwiftUI
import CoreData

struct TrackerView: View {
    @StateObject private var viewModel = MacroViewModel()
    
    // NEW: Control the sheet
    @State private var showAddMeal = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MealEntity.timestamp, ascending: false)],
        animation: .default)
    private var meals: FetchedResults<MealEntity>

    var body: some View {
        
            List {
                ForEach(meals) { meal in
                    NavigationLink(destination: MealDetailView(meal: meal)) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(meal.summary ?? "Untitled Meal")
                                    .font(.headline)
                                Text(meal.timestamp ?? Date(), style: .time)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("\(Int(meal.totalCalories)) kcal").bold()
                                Text("P:\(Int(meal.totalProtein)) C:\(Int(meal.totalCarbs)) F:\(Int(meal.totalFat))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Log")
            .toolbar {
                            
                            
                            ToolbarItem(placement: .primaryAction) {
                                Button(action: { showAddMeal.toggle() }) {
                                    Image(systemName: "plus")
                                }
                            }
                        }
            // Bind the sheets
            .sheet(isPresented: $showAddMeal) {
                // Pass the existing ViewModel so it shares API keys/logic
                AddMealView(viewModel: viewModel)
            }
        
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { meals[$0] }.forEach(PersistenceController.shared.container.viewContext.delete)
            PersistenceController.shared.save()
        }
    }
}

