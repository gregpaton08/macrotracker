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
//    - Scrollable meal list with context-menu deletion
//

import Foundation
import HealthKit
import SwiftUI

struct DailyDashboard: View {
  @Environment(\.managedObjectContext) private var viewContext
  @Environment(\.scenePhase) private var scenePhase

  /// Meals for this specific day, fetched via a date-range predicate.
  @FetchRequest var meals: FetchedResults<MealEntity>

  @State private var caloriesBurned: Double = 0.0
  #if os(iOS)
    @State private var workouts: [HKWorkout] = []
  #endif

  /// When `true`, HealthKit active-energy and workout calories are combined.
  @AppStorage("combine_workouts_and_steps") var combineSources: Bool = false

  // MARK: - Workout Type Filters

  @AppStorage("workout_filter_run") var filterRun: Bool = true
  @AppStorage("workout_filter_cycle") var filterCycle: Bool = true
  @AppStorage("workout_filter_walk") var filterWalk: Bool = true
  @AppStorage("workout_filter_strength") var filterStrength: Bool = true
  @AppStorage("workout_filter_hiit") var filterHIIT: Bool = true
  @AppStorage("workout_filter_yoga") var filterYoga: Bool = true
  @AppStorage("workout_filter_swim") var filterSwim: Bool = true
  @AppStorage("workout_filter_other") var filterOther: Bool = true

  // MARK: - Goal Ranges (synced via @AppStorage with SettingsView)

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
      predicate: NSPredicate(
        format: "timestamp >= %@ AND timestamp < %@", startOfDay as NSDate, endOfDay as NSDate),
      animation: .default
    )
  }

  // MARK: - Computed Totals

  var totalP: Double { meals.reduce(0) { $0 + $1.totalProtein } }
  var totalC: Double { meals.reduce(0) { $0 + $1.totalCarbs } }
  var totalF: Double { meals.reduce(0) { $0 + $1.totalFat } }
  var totalKcal: Double { meals.reduce(0) { $0 + $1.totalCalories } }

  #if os(iOS)
    /// Workouts filtered by user-enabled workout types.
    var filteredWorkouts: [HKWorkout] {
      let enabled: [String: Bool] = [
        "run": filterRun, "cycle": filterCycle, "walk": filterWalk,
        "strength": filterStrength, "hiit": filterHIIT, "yoga": filterYoga,
        "swim": filterSwim, "other": filterOther,
      ]
      return workouts.filter { enabled[$0.workoutActivityType.filterKey] ?? true }
    }
  #endif

  /// Total calories from HealthKit workout samples (iOS only).
  var workoutKcal: Double {
    #if os(iOS)
      return filteredWorkouts.reduce(0) {
        $0 + ($1.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0)
      }
    #else
      return 0
    #endif
  }

  /// Active energy to display — optionally includes workout calories.
  var finalBurned: Double {
    if combineSources { return caloriesBurned + workoutKcal } else { return caloriesBurned }
  }

  var body: some View {
    List {
      Section {
        VStack(spacing: 20) {

          // 1. CALORIE MATH ROW
          HStack(spacing: 15) {
            statColumn(title: "Eaten", value: totalKcal, color: .primary)

            Text("-").foregroundColor(.secondary)

            Button(action: { combineSources.toggle() }) {
              VStack(spacing: 2) {
                HStack(spacing: 2) {
                  Text("Burned")
                  Image(systemName: combineSources ? "plus.circle.fill" : "flame.fill")
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
              color: (totalKcal - finalBurned < 0 ? Theme.good : .primary))
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
            if !filteredWorkouts.isEmpty {
              Divider()
              VStack(alignment: .leading, spacing: 8) {
                Text("Workouts")
                  .font(.caption).bold().foregroundColor(.secondary).textCase(.uppercase)

                ForEach(filteredWorkouts, id: \.uuid) { workout in
                  HStack {
                    Image(systemName: workout.workoutActivityType.icon)
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
        .padding(.vertical, 16)
      }
      .listRowBackground(Theme.secondaryBackground)
      .listRowInsets(EdgeInsets())

      // 4. MEALS
      Section(header: Text("Meals")) {
        if meals.isEmpty {
          Text("No meals logged yet.")
            .italic().foregroundColor(.secondary)
            .listRowBackground(Color.clear)
        } else {
          ForEach(meals) { meal in
            NavigationLink(destination: MealDetailView(meal: meal)) {
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  Text(meal.summary ?? "Meal").font(.headline)
                  Text(
                    "F: \(Int(meal.totalFat))  C: \(Int(meal.totalCarbs))  P: \(Int(meal.totalProtein))"
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
        }
      }
    }
    .scrollContentBackground(.hidden)
    .background(Theme.background)
    .task(id: date) {
      caloriesBurned = await HealthManager.shared.fetchCaloriesBurned(for: date)
      #if os(iOS)
        workouts = await HealthManager.shared.fetchWorkouts(for: date)
      #endif
    }
    .onAppear { HealthManager.shared.requestAuthorization() }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        Task {
          caloriesBurned = await HealthManager.shared.fetchCaloriesBurned(for: date)
          #if os(iOS)
            workouts = await HealthManager.shared.fetchWorkouts(for: date)
          #endif
        }
      }
    }
  }

  /// Small vertical label + number used in the calorie math row.
  private func statColumn(title: String, value: Double, color: Color) -> some View {
    VStack(spacing: 2) {
      Text(title).font(.caption).bold().foregroundColor(.secondary)
      Text("\(Int(value))").font(.title3).bold().foregroundColor(color)
    }
  }

}

// MARK: - HKWorkoutActivityType Display Name

#if os(iOS)
  import HealthKit
  extension HKWorkoutActivityType {
    /// UserDefaults key suffix used for per-type workout filtering.
    var filterKey: String {
      switch self {
      case .running: return "run"
      case .cycling: return "cycle"
      case .walking: return "walk"
      case .traditionalStrengthTraining, .functionalStrengthTraining: return "strength"
      case .highIntensityIntervalTraining: return "hiit"
      case .yoga: return "yoga"
      case .swimming: return "swim"
      default: return "other"
      }
    }

    /// SF Symbol name for each workout type.
    var icon: String {
      switch self {
      case .running: return "figure.run.circle.fill"
      case .cycling: return "figure.outdoor.cycle"
      case .walking: return "figure.walk.circle.fill"
      case .traditionalStrengthTraining, .functionalStrengthTraining: return "dumbbell.fill"
      case .highIntensityIntervalTraining: return "bolt.heart.fill"
      case .yoga: return "figure.yoga"
      case .swimming: return "figure.pool.swim"
      default: return "figure.run.circle.fill"
      }
    }

    /// Human-readable short name for common workout types.
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
