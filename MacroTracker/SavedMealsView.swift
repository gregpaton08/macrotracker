//
//  SavedMealsView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/30/26.
//

import SwiftUI
import CoreData

struct SavedMealsView: View {
    @State private var showAddSheet = false
    @State private var searchText = ""
    
    var body: some View {
        // We pass the search text into the sub-view
        FilteredSavedMealList(filter: searchText)
            .navigationTitle("Saved Database")
            // NATIVE SEARCH BAR (iOS 15+)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search meals...")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                NavigationView {
                    EditCachedMealView(mealToEdit: nil)
                }
            }
    }
}

// Sub-View that handles the dynamic filtering
struct FilteredSavedMealList: View {
    @Environment(\.managedObjectContext) var viewContext
    
    // The dynamic fetch request
    @FetchRequest var cachedMeals: FetchedResults<CachedMealEntity>
    
    init(filter: String) {
        if filter.isEmpty {
            // No filter: Show all, sorted by name
            _cachedMeals = FetchRequest(
                sortDescriptors: [NSSortDescriptor(keyPath: \CachedMealEntity.name, ascending: true)],
                animation: .default
            )
        } else {
            // Filter: Search by name (Case-Insensitive)
            _cachedMeals = FetchRequest(
                sortDescriptors: [NSSortDescriptor(keyPath: \CachedMealEntity.name, ascending: true)],
                predicate: NSPredicate(format: "name CONTAINS[cd] %@", filter),
                animation: .default
            )
        }
    }
    
    var body: some View {
        List {
            ForEach(cachedMeals, id: \.self) { meal in
                NavigationLink(destination: EditCachedMealView(mealToEdit: meal)) {
                    VStack(alignment: .leading) {
                        Text(meal.name ?? "Unknown").font(.headline)
                        HStack {
                            Text("\(meal.portionSize ?? "1") \(meal.unit ?? "g")")
                                .font(.caption).bold()
                            Spacer()
                            // If you deleted the 'calories' attribute, use the computed calculation here
                            // Otherwise, this accesses the old stored value (or your new extension)
                            Text("\(Int(calculateCalories(meal))) kcal")
                                .font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
            .onDelete(perform: deleteItems)
        }
    }
    
    // Helper to safely get calories regardless of your data model state
    private func calculateCalories(_ meal: CachedMealEntity) -> Double {
        // Uses the extension logic: (P*4 + C*4 + F*9)
        return (meal.protein * 4) + (meal.carbs * 4) + (meal.fat * 9)
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { cachedMeals[$0] }.forEach(MealCacheManager.shared.delete)
        }
    }
}
