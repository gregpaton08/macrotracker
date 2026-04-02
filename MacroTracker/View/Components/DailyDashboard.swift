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

import CoreData
import Foundation
import HealthKit
import SwiftUI

// MARK: - Time-Proximity Meal Group

private struct MealGroup: Identifiable {
    let id: UUID = UUID()
    let meals: [MealEntity]

    var startTime: Date { meals.first?.timestamp ?? Date() }
    var endTime: Date { meals.last?.timestamp  ?? Date() }
    var kcal: Double { meals.reduce(0) { $0 + $1.totalCalories } }
    var fat: Double { meals.reduce(0) { $0 + $1.totalFat      } }
    var carbs: Double { meals.reduce(0) { $0 + $1.totalCarbs    } }
    var protein: Double { meals.reduce(0) { $0 + $1.totalProtein } }

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

    @Binding var isEditing: Bool

    @State private var mealToAddMore: MealEntity?
    @State private var mealToRetime: MealEntity?
    @State private var retimeDate: Date = Date()
    // Bulk edit
    @State private var selectedMealIDs: Set<NSManagedObjectID> = []
    @State private var showBulkRetime = false
    @State private var bulkRetimeDate: Date = Date()
    @State private var caloriesBurned: Double = 0.0
    #if os(iOS)
        @State private var workouts: [HKWorkout] = []
    #endif

    @AppStorage("combine_workouts_and_steps") var combineSources: Bool = false
    @AppStorage("energy_source") var energySource: String = "active"
    @AppStorage("show_workouts_total_energy") var showWorkoutsInTotalMode: Bool = false
    @State private var basalEnergy: Double = 0.0

    // MARK: - Workout Type Filters

    @AppStorage("workout_filter_run")      var filterRun: Bool = true
    @AppStorage("workout_filter_cycle")    var filterCycle: Bool = true
    @AppStorage("workout_filter_walk")     var filterWalk: Bool = true
    @AppStorage("workout_filter_strength") var filterStrength: Bool = true
    @AppStorage("workout_filter_hiit")     var filterHIIT: Bool = true
    @AppStorage("workout_filter_yoga")     var filterYoga: Bool = true
    @AppStorage("workout_filter_swim")     var filterSwim: Bool = true
    @AppStorage("workout_filter_other")    var filterOther: Bool = true

    // MARK: - Goal Ranges (Fallbacks)

    @AppStorage("goal_p_min") var legacyPMin: Double = 150
    @AppStorage("goal_p_max") var legacyPMax: Double = 180
    @AppStorage("goal_c_min") var legacyCMin: Double = 200
    @AppStorage("goal_c_max") var legacyCMax: Double = 300
    @AppStorage("goal_f_min") var legacyFMin: Double = 60
    @AppStorage("goal_f_max") var legacyFMax: Double = 80

    @State private var pMin: Double = 150
    @State private var pMax: Double = 180
    @State private var cMin: Double = 200
    @State private var cMax: Double = 300
    @State private var fMin: Double = 60
    @State private var fMax: Double = 80

    let date: Date

    init(date: Date, isEditing: Binding<Bool>) {
        self.date = date
        self._isEditing = isEditing
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay   = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        _meals = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \MealEntity.timestamp, ascending: false)],
            predicate: NSPredicate(
                format: "timestamp >= %@ AND timestamp < %@",
                startOfDay as NSDate, endOfDay as NSDate),
            animation: .default
        )
    }

    // MARK: - Computed Totals

    var totalP: Double { meals.reduce(0) { $0 + $1.totalProtein } }
    var totalC: Double { meals.reduce(0) { $0 + $1.totalCarbs   } }
    var totalF: Double { meals.reduce(0) { $0 + $1.totalFat     } }
    var totalKcal: Double { meals.reduce(0) { $0 + $1.totalCalories } }

    #if os(iOS)
        var filteredWorkouts: [HKWorkout] {
            let enabled: [String: Bool] = [
                "run": filterRun, "cycle": filterCycle, "walk": filterWalk,
                "strength": filterStrength, "hiit": filterHIIT,
                "yoga": filterYoga, "swim": filterSwim, "other": filterOther
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
        if energySource == "total" { return caloriesBurned + basalEnergy }
        if combineSources { return caloriesBurned + workoutKcal }
        return caloriesBurned
    }

    // MARK: - Time-Proximity Grouping

    private var mealGroups: [MealGroup] {
        var result: [MealGroup] = []
        var batch: [MealEntity] = []

        for meal in meals {
            guard let ts = meal.timestamp else { continue }
            if batch.isEmpty {
                batch = [meal]
            } else if let lastTs = batch.last?.timestamp,
                      abs(ts.timeIntervalSince(lastTs)) <= 20 * 60 {
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
                                    .font(.system(.title3, design: .rounded)).bold().foregroundColor(.orange)
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
                        ProgressRing(label: "Fat", value: totalF, min: fMin, max: fMax)
                        ProgressRing(label: "Carbs", value: totalC, min: cMin, max: cMax)
                        ProgressRing(label: "Protein", value: totalP, min: pMin, max: pMax)
                    }
                    .padding(.horizontal, 10)

                    // 3. WORKOUTS (iOS only)
                    #if os(iOS)
                        if !filteredWorkouts.isEmpty
                            && (energySource != "total" || showWorkoutsInTotalMode) {
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
                                                .font(.system(.subheadline, design: .rounded)).bold().monospacedDigit()
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
        .safeAreaInset(edge: .bottom) {
            if isEditing && !selectedMealIDs.isEmpty {
                Button {
                    let first = meals.first { selectedMealIDs.contains($0.objectID) }
                    bulkRetimeDate = first?.timestamp ?? Date()
                    showBulkRetime = true
                } label: {
                    Label(
                        "Change Time for \(selectedMealIDs.count) Meal\(selectedMealIDs.count == 1 ? "" : "s")",
                        systemImage: "clock"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding()
                .background(.bar)
            }
        }
        .onChange(of: isEditing) { newValue in
            if !newValue { selectedMealIDs.removeAll() }
        }
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
        .sheet(isPresented: $showBulkRetime) {
            NavigationStack {
                DatePicker("Time", selection: $bulkRetimeDate, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding()
                    .navigationTitle("Change Time")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showBulkRetime = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                bulkUpdateTime(to: bulkRetimeDate)
                                showBulkRetime = false
                                isEditing = false
                                selectedMealIDs.removeAll()
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
        .onAppear { 
            loadDailyGoals()
            HealthManager.shared.requestAuthorization() 
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                loadDailyGoals()
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
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(group.timeLabel)
                    .font(.caption).fontWeight(.semibold)
                Spacer()
                Text("\(Int(group.kcal)) kcal")
                    .font(.system(.caption, design: .rounded)).monospacedDigit()
            }
            Text(String(format: "F:%d  C:%d  P:%d",
                        Int(group.fat), Int(group.carbs), Int(group.protein)))
                .font(.system(.caption2, design: .rounded)).monospacedDigit()
        }
        .foregroundStyle(.secondary)
    }

// MARK: - Meal Row

    @ViewBuilder
    private func mealRow(_ meal: MealEntity) -> some View {
        if isEditing {
            Button(action: { toggleSelection(meal) }) {
                HStack(spacing: 12) {
                    Image(systemName: selectedMealIDs.contains(meal.objectID)
                          ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedMealIDs.contains(meal.objectID) ? Theme.tint : .secondary)
                        .font(.title3)
                    mealRowContent(meal)
                }
            }
            .buttonStyle(.plain)
        } else if meal.processingState == .failed {
            Button(action: {
                MacroViewModel(context: viewContext).retryAnalysis(for: meal)
            }) {
                mealRowContent(meal)
            }
            .contextMenu { deleteContextMenu(for: meal) }
        } else {
            NavigationLink(destination: MealDetailView(meal: meal)) {
                mealRowContent(meal)
            }
            .contextMenu {
                if meal.processingState == .completed {
                    if meal.portion > 0 {
                        Button { mealToAddMore = meal } label: { Label("Add More", systemImage: "plus.circle") }
                    }
                    Button {
                        retimeDate = meal.timestamp ?? Date()
                        mealToRetime = meal
                    } label: { Label("Change Time", systemImage: "clock") }
                }
                deleteContextMenu(for: meal)
            }
        }
    }

    /// The visual layout for the meal row, handling all 3 AI states
    @ViewBuilder
    private func mealRowContent(_ meal: MealEntity) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.summary ?? "Meal").font(.headline)

                switch meal.processingState {
                case .completed:
                    Text(String(format: "F:%3d  C:%3d  P:%3d", Int(meal.totalFat), Int(meal.totalCarbs), Int(meal.totalProtein)))
                        .font(.system(.caption, design: .rounded)).foregroundColor(.secondary).monospacedDigit()
                case .pending:
                    Text("Analyzing with AI...").font(.caption).foregroundColor(.secondary)
                case .failed:
                    Text("Analysis failed. Tap to retry.").font(.caption).foregroundColor(Theme.over)
                }
            }

            Spacer()

            switch meal.processingState {
            case .completed:
                VStack(alignment: .trailing) {
                    Text("\(Int(meal.totalCalories))")
                        .font(.system(.body, design: .rounded)).bold()
                    Text("kcal").font(.caption2).foregroundColor(.secondary)
                }
            case .pending:
                ProgressView()
            case .failed:
                Image(systemName: "exclamationmark.circle.fill").foregroundColor(Theme.over)
            }
        }
    }

    /// Extracts the delete button so it can be reused in both row states
    @ViewBuilder
    private func deleteContextMenu(for meal: MealEntity) -> some View {
        Button(role: .destructive) {
            withAnimation {
                viewContext.delete(meal)
                try? viewContext.save()
            }
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    // MARK: - Helpers

    private func toggleSelection(_ meal: MealEntity) {
        if selectedMealIDs.contains(meal.objectID) {
            selectedMealIDs.remove(meal.objectID)
        } else {
            selectedMealIDs.insert(meal.objectID)
        }
    }

    private func bulkUpdateTime(to newTime: Date) {
        for meal in meals where selectedMealIDs.contains(meal.objectID) {
            updateTime(of: meal, to: newTime)
        }
    }

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
            Text("\(Int(value))").font(.system(.title3, design: .rounded)).bold().foregroundColor(color)
        }
    }

    private func loadDailyGoals() {
        if let goal = DailyGoalEntity.goal(for: date, context: viewContext) {
            pMin = goal.pMin
            pMax = goal.pMax
            cMin = goal.cMin
            cMax = goal.cMax
            fMin = goal.fMin
            fMax = goal.fMax
        } else {
            pMin = legacyPMin
            pMax = legacyPMax
            cMin = legacyCMin
            cMax = legacyCMax
            fMin = legacyFMin
            fMax = legacyFMax
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
