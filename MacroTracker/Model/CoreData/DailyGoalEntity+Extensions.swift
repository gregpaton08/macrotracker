//
//  DailyGoalEntity+Extensions.swift
//  MacroTracker
//
//  Created by Gregory Paton on 3/19/26.
//

import CoreData
import Foundation

extension DailyGoalEntity {

    /// Returns the active macro goals for a specific date.
    /// If no explicit goals are set for that date, it falls back to the most recent previous goals.
    /// If there are no goals at all, it returns nil.
    static func goal(for date: Date, context: NSManagedObjectContext) -> DailyGoalEntity? {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        // 1. Try to find an exact match for today
        let request: NSFetchRequest<DailyGoalEntity> = DailyGoalEntity.fetchRequest()
        request.predicate = NSPredicate(format: "date == %@", startOfDay as NSDate)
        request.fetchLimit = 1

        if let exactMatch = try? context.fetch(request).first {
            return exactMatch
        }

        // 2. Fallback: Find the most recent goals BEFORE today
        let fallbackRequest: NSFetchRequest<DailyGoalEntity> = DailyGoalEntity.fetchRequest()
        fallbackRequest.predicate = NSPredicate(format: "date < %@", startOfDay as NSDate)
        fallbackRequest.sortDescriptors = [NSSortDescriptor(keyPath: \DailyGoalEntity.date, ascending: false)]
        fallbackRequest.fetchLimit = 1

        return try? context.fetch(fallbackRequest).first
    }

    /// Creates or updates goals for a specific date.
    /// This change will affect that day and all future days until another change is made.
    @discardableResult
    static func updateGoal(for date: Date, in context: NSManagedObjectContext, bodyweight: Double, bodyweightUnit: String, fMin: Double, fMax: Double, cMin: Double, cMax: Double, pMin: Double, pMax: Double, fMode: String, fMinGKg: Double, fMaxGKg: Double, cMode: String, cMinGKg: Double, cMaxGKg: Double, pMode: String, pMinGKg: Double, pMaxGKg: Double) -> DailyGoalEntity {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        let request: NSFetchRequest<DailyGoalEntity> = DailyGoalEntity.fetchRequest()
        request.predicate = NSPredicate(format: "date == %@", startOfDay as NSDate)

        let goal = (try? context.fetch(request).first) ?? DailyGoalEntity(context: context)

        goal.date = startOfDay
        goal.bodyweight = bodyweight
        goal.bodyweightUnit = bodyweightUnit
        goal.fMin = fMin
        goal.fMax = fMax
        goal.cMin = cMin
        goal.cMax = cMax
        goal.pMin = pMin
        goal.pMax = pMax
        goal.fMode = fMode
        goal.fMinGKg = fMinGKg
        goal.fMaxGKg = fMaxGKg
        goal.cMode = cMode
        goal.cMinGKg = cMinGKg
        goal.cMaxGKg = cMaxGKg
        goal.pMode = pMode
        goal.pMinGKg = pMinGKg
        goal.pMaxGKg = pMaxGKg

        try? context.save()
        return goal
    }
}
