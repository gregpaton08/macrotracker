//
//  TrackerView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/28/26.
//
// This is the main view where you enter in food you ate and it shows a history of food items.

import SwiftUI
import CoreData

struct TrackerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // 1. Track the selected day (Just like StatsView)
    @State private var selectedDate = Date()
    @State private var showAddMeal = false
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Date Navigator
            HStack {
                Button(action: { moveDate(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .padding()
                }
                
                Spacer()
                
                // Clicking the date resets to "Today"
                Button(action: { withAnimation { selectedDate = Date() } }) {
                    VStack {
                        Text(selectedDate, style: .date)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if Calendar.current.isDateInToday(selectedDate) {
                            Text("Today").font(.caption).foregroundColor(.blue)
                        }
                    }
                }
                
                Spacer()
                
                Button(action: { moveDate(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .padding()
                }
                // Disable "Next" if we are already on Today (optional, remove if you want to plan ahead)
                .disabled(Calendar.current.isDateInToday(selectedDate))
            }
            .padding(.vertical, 10)
            // MARK: - THE FIX
                            #if os(iOS)
            .background(
                            Color(uiColor: .secondarySystemBackground))
                            #else
            .background(
                            Color(nsColor: .controlBackgroundColor))
                            #endif
            
            // MARK: - The List (Sub-View)
            // We pass the date into this view, which handles the Core Data fetching
            DailyLogList(date: selectedDate)
        }
        .navigationTitle("Log")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            // Settings Button (iOS only)
            #if os(iOS)
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gear")
                }
            }
            #endif
            
            // Add Meal Button
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddMeal.toggle() }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddMeal) {
            // Note: AddMealView creates a NEW context, so we inject the viewContext
            AddMealView(viewModel: MacroViewModel(context: viewContext))
        }
        .sheet(isPresented: $showSettings) {
            NavigationView {
                SettingsView()
            }
        }
    }
    
    private func moveDate(by days: Int) {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) ?? Date()
        }
    }
}

// MARK: - Sub-View: The Dynamic List
struct DailyLogList: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // The Fetch Request
    @FetchRequest var meals: FetchedResults<MealEntity>
    
    // Calculate Day Totals
    var dayCalories: Int { Int(meals.reduce(0) { $0 + $1.totalCalories }) }
    var dayProtein: Int { Int(meals.reduce(0) { $0 + $1.totalProtein }) }
    var dayCarbs: Int { Int(meals.reduce(0) { $0 + $1.totalCarbs }) }
    var dayFat: Int { Int(meals.reduce(0) { $0 + $1.totalFat }) }
    
    init(date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Dynamic Predicate: Only fetch meals between 00:00 and 23:59 of 'date'
        _meals = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \MealEntity.timestamp, ascending: false)],
            predicate: NSPredicate(format: "timestamp >= %@ AND timestamp < %@", startOfDay as NSDate, endOfDay as NSDate),
            animation: .default
        )
    }
    
    var body: some View {
        List {
            // 1. Daily Summary Header (Optional, but nice to see)
            if !meals.isEmpty {
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total").font(.caption).bold().foregroundColor(.gray)
                            Text("\(dayCalories) kcal").font(.headline)
                        }
                        Spacer()
                        MacroPill(label: "P", amount: dayProtein, color: .blue)
                        MacroPill(label: "C", amount: dayCarbs, color: .green)
                        MacroPill(label: "F", amount: dayFat, color: .red)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            // 2. The Meals
            if meals.isEmpty {
                Text("No meals logged for this day.")
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
                    .listRowBackground(Color.clear)
            } else {
                ForEach(meals) { meal in
                    NavigationLink(destination: MealDetailView(meal: meal)) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(meal.summary ?? "Meal")
                                    .font(.headline)
                                Text(meal.timestamp ?? Date(), style: .time)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("\(Int(meal.totalCalories))")
                                    .bold()
                                Text("kcal")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
        }
#if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.inset)
        #endif
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { meals[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}

// Small helper for the summary header
struct MacroPill: View {
    let label: String
    let amount: Int
    let color: Color
    
    var body: some View {
        VStack {
            Text(label).font(.system(size: 8, weight: .bold))
            Text("\(amount)").font(.caption).bold()
        }
        .padding(6)
        .background(color.opacity(0.1))
        .cornerRadius(6)
        .foregroundColor(color)
    }
}
