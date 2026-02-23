//
//  MacroStatsService.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/8/26.
//
//  Provides read-only aggregation helpers over MealEntity data
//  for the Insights feature (calendar dots + averages).
//

import CoreData
import Foundation
import OSLog

/// Aggregated macros for a single calendar day, keyed by start-of-day `Date`.
struct DailyMacroTotal: Identifiable {
  let id: Date  // start-of-day, used as unique key
  let protein: Double
  let carbs: Double
  let fat: Double

  /// Calories computed via Atwater factors (P*4 + C*4 + F*9).
  var calories: Double {
    caloriesFromMacros(fat: fat, carbohydrates: carbs, protein: protein)
  }
}

/// Average daily macros over a date range. Only days with logged meals count.
struct MacroAverage {
  let protein: Double
  let carbs: Double
  let fat: Double
  let dayCount: Int  // number of days that had at least one meal

  /// Calories computed via Atwater factors (P*4 + C*4 + F*9).
  var calories: Double {
    caloriesFromMacros(fat: fat, carbohydrates: carbs, protein: protein)
  }
}

struct MacroStatsService {
  private static let logger = Logger(
    subsystem: "com.macrotracker",
    category: "MacroStatsService"
  )

  /// Fetches all meals in `[start, end)` and groups them into per-day totals.
  static func dailyTotals(
    from start: Date,
    to end: Date,
    context: NSManagedObjectContext
  ) -> [Date: DailyMacroTotal] {
    let request: NSFetchRequest<MealEntity> = MealEntity.fetchRequest()
    request.predicate = NSPredicate(
      format: "timestamp >= %@ AND timestamp < %@",
      start as NSDate,
      end as NSDate
    )
    request.sortDescriptors = [
      NSSortDescriptor(keyPath: \MealEntity.timestamp, ascending: true)
    ]

    let meals: [MealEntity]
    do {
      meals = try context.fetch(request)
    } catch {
      logger.error("Failed to fetch meals: \(error.localizedDescription)")
      return [:]
    }

    let calendar = Calendar.current
    var grouped: [Date: (p: Double, c: Double, f: Double)] = [:]

    for meal in meals {
      guard let ts = meal.timestamp else { continue }
      let dayKey = calendar.startOfDay(for: ts)
      var bucket = grouped[dayKey, default: (0, 0, 0)]
      bucket.p += meal.totalProtein
      bucket.c += meal.totalCarbs
      bucket.f += meal.totalFat
      grouped[dayKey] = bucket
    }

    return grouped.reduce(into: [:]) { result, pair in
      result[pair.key] = DailyMacroTotal(
        id: pair.key,
        protein: pair.value.p,
        carbs: pair.value.c,
        fat: pair.value.f
      )
    }
  }

  /// Computes average daily macros over the given date range.
  /// Only days with logged meals count toward the average.
  static func averages(
    from start: Date,
    to end: Date,
    context: NSManagedObjectContext
  ) -> MacroAverage {
    let totals = dailyTotals(from: start, to: end, context: context)
    let count = totals.count
    guard count > 0 else {
      return MacroAverage(protein: 0, carbs: 0, fat: 0, dayCount: 0)
    }

    let sumP = totals.values.reduce(0) { $0 + $1.protein }
    let sumC = totals.values.reduce(0) { $0 + $1.carbs }
    let sumF = totals.values.reduce(0) { $0 + $1.fat }

    return MacroAverage(
      protein: sumP / Double(count),
      carbs: sumC / Double(count),
      fat: sumF / Double(count),
      dayCount: count
    )
  }
}
