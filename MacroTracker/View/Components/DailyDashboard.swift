//
//  DailyDashboard.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/5/26.
//
//  Full-day summary shown inside each TrackerView page.
//  Displays:
//    - Calorie math row (Eaten − Burned = Net)
//    - Three macro progress rings (Fat / Carbs / Protein)
//    - HealthKit workout breakdown (iOS only)
//    - Meal list grouped by time proximity: meals within 20 minutes of each
//      other form a group, with a header showing the time range.
//

import Foundation
import HealthKit
import SwiftUI

// MARK: - Time-Proximity Meal Group

private struct MealGroup: Identifiable {
    let id: UUID = UUID()
    let meals: [MealEntity]

    var startTime: Date { meals.first?.timestamp ?? Date() }
    var endTime:   Date { meals.last?.timestamp  ?? Date() }
    var kcal: Double { meals.reduce(0) { $0 + $1.totalCalories } }

    /// "12:00 PM" for a single meal, "12:00 PM – 12:35 PM" for multiple.
    var timeLabel: String {
        let f = DateFormatter()
        f.timeStyle = .short
        let start = f.string(from: startTime)
        guard meals.count > 1 else { return start }
        return "\(start) – \(f.string(from: endTime))"
    }
}

// MARK: - DailyDashboard

struct DailyDashboard: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase

    /// Meals for this specific day, sorted oldest-first so the grouping
    /// algorithm visits them in chronological order.
    @FetchRequest var meals: FetchedResults<MealEntity>

    @State private var mealToAddMore: MealEntity?
    @State private var mealToRetime: MealEntity?
    @State private var retimeDate: Date = Date()
    @State private var caloriesBurned: Double = 0.0
    #if os(iOS)
        @State private var workouts: [HKWorkout] = []
    #endif

    @AppStorage("combine_workouts_and_steps") var combineSources: Bool = false
    @AppStorage("energy_source") var energySource: String = "active"
    @AppStorage("show_workouts_total_energy") var showWorkoutsInTotalMode: Bool = false
    @State private var basalEnergy: Double = 0.0

    // MARK: - Workout Type Filters

    @AppStorage("workout_filter_run")      var filterRun:      Bool = true
    @AppStorage("workout_filter_cycle")    var filterCycle:    Bool = true
    @AppStorage("workout_filter_walk")     var filterWalk:     Bool = true
    @AppStorage("workout_filter_strength") var filterStrength: Bool = true
    @AppStorage("workout_filter_hiit")     var filterHIIT:     Bool = true
    @AppStorage("workout_filter_yoga")     var filterYoga:     Bool = true
    @AppStorage("workout_filter_swim")     var filterSwim:     Bool = true
    @AppStorage("workout_filter_other")    var filterOther:    Bool = true

    // MARK: - Goal Ranges

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
        let endOfDay   = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        _meals = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \MealEntity.timestamp, ascending: true)],
            predicate: NSPredicate(
                format: "timestamp >= %@ AND timestamp < %@",
                startOfDay as NSDate, endOfDay as NSDate),
            animation: .default
        )
    }

    // MARK: - Computed Totals

    var totalP:    Double { meals.reduce(0) { $0 + $1.totalProtein } }
    var totalC:    Double { meals.reduce(0) { $0 + $1.totalCarbs   } }
    var totalF:    Double { meals.reduce(0) { $0 + $1.totalFat     } }
    var totalKcal: Double { meals.reduce(0) { $0 + $1.totalCalories } }

    #if os(iOS)
        var filteredWorkouts: [HKWorkout] {
            let enabled: [String: Bool] = [
                "run": filterRun, "cycle": filterCycle, "walk": filterWalk,
                "strength": filterStrength, "hiit": filterHIIT,
                "yoga": filterYoga, "swim": filterSwim, "other": filterOther,
            ]
            return workouts.filter { enabled[$0.workoutActivityType.filterKey] ?? true }
        }
    #endif

    var workoutKcal: Double {
        #if os(iOS)
            return filteredWorkouts.reduce(0) {
                $0 + ($1.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0)
            }
        #else
            return 0
        #endif
    }

    var finalBurned: Double {
        if energySource == "total"  { return caloriesBurned + basalEnergy }
        if combineSources           { return caloriesBurned + workoutKcal }
        return caloriesBurned
    }

    // MARK: - Time-Proximity Grouping

    /// Groups meals so that consecutive meals within 20 minutes of each other
    /// form a single group. The FetchRequest is sorted ascending, so meals
    /// arrive in chronological order.
    private var mealGroups: [MealGroup] {
        var result: [MealGroup] = []
        var batch:  [MealEntity] = []

        for meal in meals {
            guard let ts = meal.timestamp else { continue }
            if batch.isEmpty {
                batch = [meal]
            } else if let lastTs = batch.last?.timestamp,
                      ts.timeIntervalSince(lastTs) <= 20 * 60 {
                batch.append(meal)
            } else {
                result.append(MealGroup(meals: batch))
                batch = [meal]
            }
        }
        if !batch.isEmpty { result.append(MealGroup(meals: batch)) }
        return result
    }

    // MARK: - Body

    var body: some View {
        List {
            // Summary card (calorie math + rings + workouts)
            Section {
                VStack(spacing: 20) {

                    // 1. CALORIE MATH ROW
                    HStack(spacing: 15) {
                        statColumn(title: "Eaten", value: totalKcal, color: .primary)

                        Text("-").foregroundColor(.secondary)

                        Button(action: {
                            if energySource != "total" { combineSources.toggle() }
                        }) {
                            VStack(spacing: 2) {
                                HStack(spacing: 2) {
                                    Text("Burned")
                                    Image(systemName: energySource == "total"
                                          ? "bolt.fill"
                                          : (combineSources ? "plus.circle.fill" : "flame.fill"))
                                        .font(.caption2)
                                }
                                .font(.caption).bold().foregroundColor(.secondary)

                                Text("\(Int(finalBurned))")
                                    .font(.title3).bold().foregroundColor(.orange)
                                    .contentTransition(.numericText())
                            }
                        }
                        .buttonStyle(.plain)

                        Text("=").foregroundColor(.secondary)

                        statColumn(
                            title: "Net", value: totalKcal - finalBurned,
                            color: totalKcal - finalBurned < 0 ? Theme.good : .primary)
                    }
                    .padding(.bottom, 5)

                    // 2. RINGS
                    HStack(spacing: 15) {
                        ProgressRing(label: "Fat",     value: totalF, min: fMin, max: fMax)
                        ProgressRing(label: "Carbs",   value: totalC, min: cMin, max: cMax)
                        ProgressRing(label: "Protein", value: totalP, min: pMin, max: pMax)
                    }
                    .padding(.horizontal, 10)

                    // 3. WORKOUTS (iOS only)
                    #if os(iOS)
                        if !filteredWorkouts.isEmpty
                            && (energySource != "total" || showWorkoutsInTotalMode)
                        {
                            Divider()
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Workouts")
                                    .font(.caption).bold().foregroundColor(.secondary)
                                    .textCase(.uppercase)

                                ForEach(filteredWorkouts, id: \.uuid) { workout in
                                    HStack {
                                        Image(systemName: workout.workoutActivityType.icon)
                                            .foregroundColor(.orange)
                                        Text(workout.workoutActivityType.name)
                                            .font(.subheadline).bold()
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
                .padding(.vertical, 16)
            }
            .listRowBackground(Theme.secondaryBackground)
            .listRowInsets(EdgeInsets())

            // 4. MEALS — grouped by time proximity
            if meals.isEmpty {
                Section {
                    Text("No meals logged yet.")
                        .italic().foregroundColor(.secondary)
                        .listRowBackground(Color.clear)
                }
            } else {
                ForEach(mealGroups) { group in
                    Section {
                        ForEach(group.meals) { meal in
                            mealRow(meal)
                        }
                    } header: {
                        groupHeader(group)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .sheet(item: $mealToAddMore) { meal in
            AddMoreView(meal: meal)
        }
        .sheet(item: $mealToRetime) { meal in
            NavigationStack {
                DatePicker("Time", selection: $retimeDate, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding()
                    .navigationTitle("Change Time")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { mealToRetime = nil }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                updateTime(of: meal, to: retimeDate)
                                mealToRetime = nil
                            }
                            .fontWeight(.semibold)
                        }
                    }
            }
            .presentationDetents([.height(280)])
        }
        .task(id: date) {
            caloriesBurned = await HealthManager.shared.fetchCaloriesBurned(for: date)
            basalEnergy    = await HealthManager.shared.fetchBasalEnergyBurned(for: date)
            #if os(iOS)
                workouts = await HealthManager.shared.fetchWorkouts(for: date)
            #endif
        }
        .onAppear { HealthManager.shared.requestAuthorization() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task {
                    caloriesBurned = await HealthManager.shared.fetchCaloriesBurned(for: date)
                    basalEnergy    = await HealthManager.shared.fetchBasalEnergyBurned(for: date)
                    #if os(iOS)
                        workouts = await HealthManager.shared.fetchWorkouts(for: date)
                    #endif
                }
            }
        }
    }

    // MARK: - Group Header

    @ViewBuilder
    private func groupHeader(_ group: MealGroup) -> some View {
        HStack {
            Text(group.timeLabel)
                .font(.caption).fontWeight(.semibold)
            Spacer()
            Text("\(Int(group.kcal)) kcal")
                .font(.caption).monospacedDigit()
        }
        .foregroundStyle(.secondary)
    }

    // MARK: - Meal Row

    @ViewBuilder
    private func mealRow(_ meal: MealEntity) -> some View {
        NavigationLink(destination: MealDetailView(meal: meal)) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.summary ?? "Meal").font(.headline)
                    Text(
                        String(
                            format: "F:%3d  C:%3d  P:%3d",
                            Int(meal.totalFat), Int(meal.totalCarbs), Int(meal.totalProtein))
                    )
                    .font(.caption).foregroundColor(.secondary).monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("\(Int(meal.totalCalories))").bold()
                    Text("kcal").font(.caption2).foregroundColor(.secondary)
                }
            }
        }
        .contextMenu {
            if meal.portion > 0 {
                Button {
                    mealToAddMore = meal
                } label: {
                    Label("Add More", systemImage: "plus.circle")
                }
            }
            Button {
                retimeDate = meal.timestamp ?? Date()
                mealToRetime = meal
            } label: {
                Label("Change Time", systemImage: "clock")
            }
            Button(role: .destructive) {
                withAnimation {
                    viewContext.delete(meal)
                    try? viewContext.save()
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    // MARK: - Helpers

    /// Updates the time portion of a meal's timestamp while keeping its date unchanged.
    private func updateTime(of meal: MealEntity, to newTime: Date) {
        guard let existing = meal.timestamp else { return }
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: existing)
        let time = calendar.dateComponents([.hour, .minute], from: newTime)
        components.hour   = time.hour
        components.minute = time.minute
        meal.timestamp = calendar.date(from: components) ?? existing
        try? viewContext.save()
    }

    private func statColumn(title: String, value: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).bold().foregroundColor(.secondary)
            Text("\(Int(value))").font(.title3).bold().foregroundColor(color)
        }
    }
}

// MARK: - HKWorkoutActivityType Helpers

#if os(iOS)
    import HealthKit
    extension HKWorkoutActivityType {
        var filterKey: String {
            switch self {
            case .running:  return "run"
            case .cycling:  return "cycle"
            case .walking:  return "walk"
            case .traditionalStrengthTraining, .functionalStrengthTraining: return "strength"
            case .highIntensityIntervalTraining: return "hiit"
            case .yoga:     return "yoga"
            case .swimming: return "swim"
            default:        return "other"
            }
        }

        var icon: String {
            switch self {
            case .running:  return "figure.run.circle.fill"
            case .cycling:  return "figure.outdoor.cycle"
            case .walking:  return "figure.walk.circle.fill"
            case .traditionalStrengthTraining, .functionalStrengthTraining: return "dumbbell.fill"
            case .highIntensityIntervalTraining: return "bolt.heart.fill"
            case .yoga:     return "figure.yoga"
            case .swimming: return "figure.pool.swim"
            default:        return "figure.run.circle.fill"
            }
        }

        var name: String {
            switch self {
            case .running:  return "Run"
            case .cycling:  return "Cycle"
            case .walking:  return "Walk"
            case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength"
            case .highIntensityIntervalTraining: return "HIIT"
            case .yoga:     return "Yoga"
            case .swimming: return "Swim"
            default:        return "Workout"
            }
        }
    }
#endif
