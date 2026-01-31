//
//  SavedMealsView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/30/26.
//

import SwiftUI
import CoreData

struct SavedMealsView: View {
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \CachedMealEntity.name, ascending: true)],
        animation: .default)
    private var cachedMeals: FetchedResults<CachedMealEntity>
    
    @State private var showAddSheet = false
    
    var body: some View {
        List {
            ForEach(cachedMeals, id: \.self) { meal in
                // Tap to Edit
                NavigationLink(destination: EditCachedMealView(mealToEdit: meal)) {
                    VStack(alignment: .leading) {
                        Text(meal.name ?? "Unknown").font(.headline)
                        HStack {
                            Text("\(meal.portionSize ?? "1") \(meal.unit ?? "g")")
                                .font(.caption).bold()
                            Spacer()
                            Text("\(Int(meal.calories)) kcal")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .onDelete(perform: deleteItems)
        }
        .navigationTitle("Saved Database")
        .toolbar {
            // The "Add New" Button
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        // The "Add New" Sheet
        .sheet(isPresented: $showAddSheet) {
            NavigationView {
                EditCachedMealView(mealToEdit: nil)
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { cachedMeals[$0] }.forEach(MealCacheManager.shared.delete)
        }
    }
}
