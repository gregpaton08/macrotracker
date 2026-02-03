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
    
    // Date State
    @State private var selectedDate = Date()
    @State private var showAddMeal = false
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Date Navigator
            HStack {
                Button(action: { moveDate(by: -1) }) {
                    Image(systemName: "chevron.left").padding()
                }
                
                Spacer()
                
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
                    Image(systemName: "chevron.right").padding()
                }
            }
            .padding(.vertical, 10)
#if os(iOS)
            .background(
                Color(uiColor: .secondarySystemBackground))
#else
            .background(
                Color(nsColor: .controlBackgroundColor))
#endif
            
            // MARK: - Combined Dashboard
            DailyDashboard(date: selectedDate)
        }
        .navigationTitle("Tracker")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gear")
                }
            }
#endif
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddMeal.toggle() }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddMeal) {
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

// MARK: - The Unified Dashboard
struct DailyDashboard: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // 1. Fetch Meals
    @FetchRequest var meals: FetchedResults<MealEntity>
    
    // 2. HealthKit State
    @State private var caloriesBurned: Double = 0.0
    
#if os(iOS)
    @State private var workouts: [HKWorkout] = []
#endif
    
    // 3. Goals
    @AppStorage("goal_p_min") var pMin: Double = 150
    @AppStorage("goal_p_max") var pMax: Double = 180
    @AppStorage("goal_c_min") var cMin: Double = 200
    @AppStorage("goal_c_max") var cMax: Double = 300
    @AppStorage("goal_f_min") var fMin: Double = 60
    @AppStorage("goal_f_max") var fMax: Double = 80
    
    let date: Date
    
    init(date: Date) {
        self.date = date
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        _meals = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \MealEntity.timestamp, ascending: false)],
            predicate: NSPredicate(format: "timestamp >= %@ AND timestamp < %@", startOfDay as NSDate, endOfDay as NSDate),
            animation: .default
        )
    }
    
    // Totals
    var totalP: Double { meals.reduce(0) { $0 + $1.totalProtein } }
    var totalC: Double { meals.reduce(0) { $0 + $1.totalCarbs } }
    var totalF: Double { meals.reduce(0) { $0 + $1.totalFat } }
    var totalKcal: Double { meals.reduce(0) { $0 + $1.totalCalories } }
    
    var body: some View {
        List {
            // SECTION 1: STATS HEADER (Scrolls with list)
            Section {
                VStack(spacing: 20) {
                    // A. Calorie Math
                    HStack(spacing: 20) {
                        VStack {
                            Text("Eaten").font(.caption).bold().foregroundColor(.secondary)
                            Text("\(Int(totalKcal))").font(.title3).bold()
                        }
                        Text("-").foregroundColor(.secondary)
                        VStack {
                            Text("Burned").font(.caption).bold().foregroundColor(.secondary)
                            Text("\(Int(caloriesBurned))").font(.title3).bold().foregroundColor(.orange)
                        }
                        Text("=").foregroundColor(.secondary)
                        VStack {
                            Text("Net").font(.caption).bold().foregroundColor(.secondary)
                            Text("\(Int(totalKcal - caloriesBurned))")
                                .font(.title3).bold()
                                .foregroundColor(totalKcal - caloriesBurned < 0 ? .green : .primary)
                        }
                    }
                    .padding(.bottom, 5)
                    
                    // B. Rings
                    HStack(spacing: 15) {
                        ProgressRing(label: "Fat", value: totalF, min: fMin, max: fMax)
                        ProgressRing(label: "Carbs", value: totalC, min: cMin, max: cMax)
                        ProgressRing(label: "Protein", value: totalP, min: pMin, max: pMax)
                    }
                    .padding(.horizontal, 20) // FIX: Add breathing room on the sides
                    
#if os(iOS)
                    if !workouts.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Workouts")
                                .font(.caption).bold()
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            ForEach(workouts, id: \.uuid) { workout in
                                HStack {
                                    Image(systemName: "figure.run.circle.fill") // Generic icon
                                        .foregroundColor(.orange)
                                    
                                    Text(workout.workoutActivityType.name)
                                        .font(.subheadline).bold()
                                    
                                    Spacer()
                                    
                                    // Show duration
                                    Text("\(Int(workout.duration / 60)) min")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    // Show calories
                                    if let energy = workout.totalEnergyBurned {
                                        Text("\(Int(energy.doubleValue(for: .kilocalorie()))) kcal")
                                            .font(.subheadline).bold()
                                            .monospacedDigit()
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(.horizontal, 10)
                    }
#endif
                }
                .padding(.vertical, 10)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets()) // Removes side padding so rings can be full width
            
            
            
            // SECTION 2: MEALS
            Section(header: Text("Meals")) {
                if meals.isEmpty {
                    Text("No meals logged.")
                        .foregroundColor(.gray)
                } else {
                    ForEach(meals) { meal in
                        NavigationLink(destination: MealDetailView(meal: meal)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(meal.summary ?? "Meal")
                                        .font(.headline)
                                    
                                    // MARK: - THE FIX
                                    // Replaced Timestamp with Macro Breakdown
                                    Text("F: \(Int(meal.totalFat))   C: \(Int(meal.totalCarbs))   P: \(Int(meal.totalProtein))")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    // Optional: Monospaced font aligns numbers better
                                        .monospacedDigit()
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
        }
#if os(iOS)
        .listStyle(.insetGrouped)
#else
        .listStyle(.inset)
#endif
        // HealthKit Trigger
        .task(id: date) {
            caloriesBurned = await HealthManager.shared.fetchCaloriesBurned(for: date)
#if os(iOS)
            workouts = await HealthManager.shared.fetchWorkouts(for: date)
#endif
        }
        .onAppear {
            HealthManager.shared.requestAuthorization()
        }
        .onAppear {
            HealthManager.shared.requestAuthorization()
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { meals[$0] }.forEach(viewContext.delete)
            try? viewContext.save()
        }
    }
}


// Ensure ProgressRing is defined here or in a separate file (Reuse code from previous step)

// Helper to name workouts nicely
#if os(iOS)
import HealthKit
extension HKWorkoutActivityType {
    var name: String {
        switch self {
        case .running: return "Run"
        case .cycling: return "Cycle"
        case .walking: return "Walk"
        case .traditionalStrengthTraining: return "Strength"
        case .functionalStrengthTraining: return "Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .yoga: return "Yoga"
        case .swimming: return "Swim"
        default: return "Workout"
        }
    }
}
#endif
