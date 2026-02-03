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
    
    // Request Permission
    func requestAuthorization() {
        #if os(iOS)
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let burnedType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        
        // We only need read access for now
        healthStore.requestAuthorization(toShare: [], read: [burnedType]) { success, error in
            if let error = error {
                print("HealthKit Auth Error: \(error.localizedDescription)")
            }
        }
        #endif
    }
    
    // Fetch Calories for a specific day
    func fetchCaloriesBurned(for date: Date) async -> Double {
        #if os(iOS)
        guard HKHealthStore.isHealthDataAvailable() else { return 0 }
        
        let calorieType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        
        // Create the predicate for "Start of Day" to "End of Day"
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
                
                // Convert to Kilocalories
                let value = sum.doubleValue(for: HKUnit.kilocalorie())
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
        #else
        return 0.0 // Mac always returns 0
        #endif
    }
}
