//
//  HealthManager.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/2/26.
//
//  Singleton that reads active energy burned and workout data from HealthKit.
//  Provides async helpers consumed by DailyDashboard to display calorie burn
//  and workout breakdowns.
//

import Foundation
import OSLog
#if os(iOS)
import HealthKit
#endif

class HealthManager: ObservableObject {
    static let shared = HealthManager()
    private let logger = Logger(subsystem: "com.macrotracker", category: "HealthManager")

    /// `true` when the user has denied HealthKit access; drives a UI banner.
    @Published var authorizationDenied = false

    #if os(iOS)
    let healthStore = HKHealthStore()
    #endif

    // MARK: - Authorization

    /// Requests read-only access to active energy burned and workout samples.
    func requestAuthorization() {
        #if os(iOS)
        guard HKHealthStore.isHealthDataAvailable() else {
            logger.warning("HealthKit not available on this device.")
            return
        }

        // 1. Add .workoutType() to the read list
        let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let workoutType = HKObjectType.workoutType()

        let readTypes: Set<HKObjectType> = [activeEnergy, workoutType]

        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
            if let error = error {
                self.logger.error("HealthKit auth error: \(error.localizedDescription)")
            }
            if !success {
                self.logger.warning("HealthKit authorization denied. Calorie data will be unavailable.")
                DispatchQueue.main.async {
                    self.authorizationDenied = true
                }
            }
        }
        #endif
    }
    
    // MARK: - Active Energy

    /// Returns total active energy burned (kcal) for the given calendar day.
    func fetchCaloriesBurned(for date: Date) async -> Double {
        #if os(iOS)
        guard HKHealthStore.isHealthDataAvailable() else { return 0 }
        let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: calorieType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
                guard let result = result, let sum = result.sumQuantity() else {
                    continuation.resume(returning: 0.0)
                    return
                }
                continuation.resume(returning: sum.doubleValue(for: HKUnit.kilocalorie()))
            }
            healthStore.execute(query)
        }
        #else
        return 0.0
        #endif
    }
    
    // MARK: - Workouts

    /// Returns all `HKWorkout` samples recorded on the given calendar day,
    /// sorted by end date (newest first).
    func fetchWorkouts(for date: Date) async -> [HKWorkout] {
        #if os(iOS)
        guard HKHealthStore.isHealthDataAvailable() else { return [] }
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Predicate: Workouts that happened today
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: .workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                
                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: workouts)
            }
            healthStore.execute(query)
        }
        #else
        return []
        #endif
    }
}
