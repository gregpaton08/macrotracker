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
    
    var body: some View {
        List {
            ForEach(cachedMeals, id: \.self) { meal in
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
            .onDelete(perform: deleteItems)
        }
        .navigationTitle("Saved Database")
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { cachedMeals[$0] }.forEach(MealCacheManager.shared.delete)
        }
    }
}
