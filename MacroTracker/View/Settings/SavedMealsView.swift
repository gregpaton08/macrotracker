//
//  SavedMealsView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/30/26.
//
//  Searchable list of all CachedMealEntity templates.
//  Users can add, edit, and swipe-to-delete saved meals.
//  Search filtering is handled by the inner FilteredSavedMealList
//  which rebuilds its @FetchRequest predicate on each keystroke.
//

import CoreData
import SwiftUI

struct SavedMealsView: View {
    @State private var showAddSheet = false
    @State private var searchText = ""

    var body: some View {
        FilteredSavedMealList(filter: searchText)
            .navigationTitle("Saved Database")
            // NATIVE SEARCH BAR (iOS 15+)
            #if os(iOS)
                // On iPhone: Force it to stay visible in the "Drawer"
                .searchable(
                    text: $searchText, placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search meals...")
            #else
                // On Mac: Use default placement (automatically goes to the top of the list or toolbar)
                .searchable(text: $searchText, prompt: "Search meals...")
            #endif
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

/// Inner list view that re-creates its `@FetchRequest` whenever the filter text changes.
struct FilteredSavedMealList: View {
    @Environment(\.managedObjectContext) var viewContext

    // The dynamic fetch request
    @FetchRequest var cachedMeals: FetchedResults<CachedMealEntity>

    init(filter: String) {
        if filter.isEmpty {
            // No filter: Show all, sorted by name
            _cachedMeals = FetchRequest(
                sortDescriptors: [
                    NSSortDescriptor(keyPath: \CachedMealEntity.name, ascending: true)
                ],
                animation: .default
            )
        } else {
            // Filter: Search by name (Case-Insensitive)
            _cachedMeals = FetchRequest(
                sortDescriptors: [
                    NSSortDescriptor(keyPath: \CachedMealEntity.name, ascending: true)
                ],
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

    /// Computes calories via Atwater factors (P*4 + C*4 + F*9).
    private func calculateCalories(_ meal: CachedMealEntity) -> Double {
        (meal.protein * 4) + (meal.carbs * 4) + (meal.fat * 9)
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { cachedMeals[$0] }.forEach(MealCacheManager.shared.delete)
        }
    }
}
