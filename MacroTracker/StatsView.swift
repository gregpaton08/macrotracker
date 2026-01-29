//
//  StatsView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/28/26.
//

import SwiftUI
import Charts // Requires iOS 16+
import CoreData

struct StatsView: View {
    // 1. Fetch Request filtered to "Today"
    @FetchRequest var todaysFoods: FetchedResults<FoodEntity>

    init() {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        // Dynamic predicate initialization
        _todaysFoods = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(format: "timestamp >= %@", startOfDay as NSDate),
            animation: .default
        )
    }
    
    // 2. Compute Totals
    var totals: [MacroData] {
        let p = todaysFoods.reduce(0) { $0 + $1.protein }
        let c = todaysFoods.reduce(0) { $0 + $1.carbs }
        let f = todaysFoods.reduce(0) { $0 + $1.fat }
        
        return [
            MacroData(type: "Protein", grams: p, color: .blue),
            MacroData(type: "Carbs", grams: c, color: .green),
            MacroData(type: "Fat", grams: f, color: .red)
        ]
    }

    var body: some View {
        NavigationView {
            VStack {
                // Summary Text
                HStack(spacing: 20) {
                    VStack {
                        Text("Calories").font(.caption).foregroundColor(.secondary)
                        Text("\(Int(todaysFoods.reduce(0){ $0 + $1.calories }))")
                            .font(.title).bold()
                    }
                    Divider().frame(height: 40)
                    VStack {
                        Text("Entries").font(.caption).foregroundColor(.secondary)
                        Text("\(todaysFoods.count)")
                            .font(.title).bold()
                    }
                }
                .padding()
                
                // The Chart
                if todaysFoods.isEmpty {
                    Spacer()
                    Text("No food logged today.").foregroundColor(.gray)
                    Spacer()
                } else {
                    Chart(totals) { item in
                        BarMark(
                            x: .value("Macro", item.type),
                            y: .value("Grams", item.grams)
                        )
                        .foregroundStyle(item.color)
                        .annotation(position: .top) {
                            Text("\(Int(item.grams))g")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(height: 300)
                    .padding()
                }
                
                Spacer()
            }
            .navigationTitle("Today's Macros")
        }
    }
}

// Simple struct for the Chart
struct MacroData: Identifiable {
    let id = UUID()
    let type: String
    let grams: Double
    let color: Color
}
