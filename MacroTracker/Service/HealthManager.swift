//
//  HealthManager.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/2/26.
//

import Foundation
#if os(iOS)
import HealthKit
#endif

class HealthManager: ObservableObject {
    static let shared = HealthManager()
    
    #if os(iOS)
    let healthStore = HKHealthStore()
    #endif
    
    func requestAuthorization() {
        #if os(iOS)
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        // 1. Add .workoutType() to the read list
        let activeEnergy = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let workoutType = HKObjectType.workoutType()
        
        let readTypes: Set<HKObjectType> = [activeEnergy, workoutType]
        
        healthStore.requestAuthorization(toShare: [], read: readTypes) { success, error in
            if let error = error {
                print("HealthKit Auth Error: \(error.localizedDescription)")
            }
        }
        #endif
    }
    
    // Fetch Total Active Calories (Existing)
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
    
    // 2. NEW: Fetch Specific Workouts
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
