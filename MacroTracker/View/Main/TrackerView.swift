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
    
    // ... FetchRequests and existing Init ...
    @FetchRequest var meals: FetchedResults<MealEntity>
    
    // HealthKit Data
    @State private var caloriesBurned: Double = 0.0 // Active Energy (Steps)
    #if os(iOS)
    @State private var workouts: [HKWorkout] = []
    #endif
    
    // MARK: - NEW SETTING
    // Toggle this to fix your specific data issue
    @AppStorage("combine_workouts_and_steps") var combineSources: Bool = false
    
    // ... Goals Init ...
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
    
    // Math Helpers
    var totalP: Double { meals.reduce(0) { $0 + $1.totalProtein } }
    var totalC: Double { meals.reduce(0) { $0 + $1.totalCarbs } }
    var totalF: Double { meals.reduce(0) { $0 + $1.totalFat } }
    var totalKcal: Double { meals.reduce(0) { $0 + $1.totalCalories } }
    
    // Workouts Total
    var workoutKcal: Double {
        #if os(iOS)
        return workouts.reduce(0) { $0 + ($1.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0) }
        #else
        return 0
        #endif
    }
    
    // MARK: - THE SMART CALCULATION
    var finalBurned: Double {
        if combineSources {
            // Your Fix: Add them together (Background Steps + External Workout)
            return caloriesBurned + workoutKcal
        } else {
            // Standard: Active Energy is the source of truth
            return caloriesBurned
        }
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 20) {
                    
                    // 1. CALORIE MATH ROW
                    HStack(spacing: 15) {
                        // IN
                        VStack {
                            Text("Eaten").font(.caption).bold().foregroundColor(.secondary)
                            Text("\(Int(totalKcal))").font(.title3).bold()
                        }
                        
                        Text("-").foregroundColor(.secondary)
                        
                        // OUT (Clickable to Toggle Mode)
                        Button(action: { combineSources.toggle() }) {
                            VStack {
                                HStack(spacing: 4) {
                                    Text("Burned")
                                    // Visual indicator of the mode
                                    Image(systemName: combineSources ? "plus.circle.fill" : "flame.fill")
                                        .font(.caption2)
                                }
                                .font(.caption).bold().foregroundColor(.secondary)
                                
                                Text("\(Int(finalBurned))")
                                    .font(.title3).bold().foregroundColor(.orange)
                                    .contentTransition(.numericText())
                            }
                        }
                        .buttonStyle(.plain) // Removes default button styling
                        
                        Text("=").foregroundColor(.secondary)
                        
                        // NET
                        VStack {
                            Text("Net").font(.caption).bold().foregroundColor(.secondary)
                            Text("\(Int(totalKcal - finalBurned))")
                                .font(.title3).bold()
                                .foregroundColor(totalKcal - finalBurned < 0 ? .green : .primary)
                        }
                    }
                    .padding(.bottom, 5)
                    
                    // 2. EXPLANATION (Only appears if Workouts exist)
                    #if os(iOS)
                    if !workouts.isEmpty {
                        HStack {
                            Text("Active: \(Int(caloriesBurned))")
                            Spacer()
                            Text("+")
                            Spacer()
                            Text("Workouts: \(Int(workoutKcal))")
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 40)
                        
                        if combineSources {
                            Text("Combining Steps & Workouts")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    #endif

                    // ... RINGS ...
                    HStack(spacing: 15) {
                        ProgressRing(label: "Protein", value: totalP, min: pMin, max: pMax)
                        ProgressRing(label: "Carbs", value: totalC, min: cMin, max: cMax)
                        ProgressRing(label: "Fat", value: totalF, min: fMin, max: fMax)
                    }
                    .padding(.horizontal, 20)

                    // ... WORKOUTS LIST ...
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
                                    Image(systemName: "figure.run.circle.fill")
                                        .foregroundColor(.orange)
                                    Text(workout.workoutActivityType.name).font(.subheadline).bold()
                                    Spacer()
                                    if let energy = workout.totalEnergyBurned {
                                        Text("\(Int(energy.doubleValue(for: .kilocalorie()))) kcal")
                                            .font(.subheadline).bold().monospacedDigit()
                                    }
                                }
                            }
                        }
                    }
                    #endif
                }
                .padding(.vertical, 10)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            
            // ... MEALS SECTION ...
            Section(header: Text("Meals")) {
                if meals.isEmpty {
                    Text("No meals logged.")
                        .foregroundColor(.gray)
                } else {
                    ForEach(meals) { meal in
                        NavigationLink(destination: MealDetailView(meal: meal)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(meal.summary ?? "Meal").font(.headline)
                                    Text("F: \(Int(meal.totalFat))   C: \(Int(meal.totalCarbs))   P: \(Int(meal.totalProtein))")
                                        .font(.caption).foregroundColor(.secondary).monospacedDigit()
                                }
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("\(Int(meal.totalCalories))").bold()
                                    Text("kcal").font(.caption2).foregroundColor(.gray)
                                }
                            }
                        }
                    }
                    .onDelete(perform: deleteItems)
                }
            }
        }
        .task(id: date) {
            caloriesBurned = await HealthManager.shared.fetchCaloriesBurned(for: date)
            #if os(iOS)
            workouts = await HealthManager.shared.fetchWorkouts(for: date)
            #endif
        }
        .onAppear { HealthManager.shared.requestAuthorization() }
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
