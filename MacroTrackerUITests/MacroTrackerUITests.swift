//
//  MacroTrackerTests.swift
//  MacroTrackerTests
//
//  Created by Gregory Paton on 1/25/26.
//

import XCTest
import CoreData
@testable import MacroTracker

final class MacroTrackerTests: XCTestCase {

    var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        // Use the in-memory persistence controller for isolated testing
        let controller = PersistenceController(inMemory: true)
        context = controller.container.viewContext
    }

    override func tearDownWithError() throws {
        context = nil
    }

    // MARK: - Logic Tests

    func testCalorieCalculation() {
        // Given
        let p: Double = 30 // 120 kcal
        let c: Double = 40 // 160 kcal
        let f: Double = 10 // 90 kcal
        // Total should be 370
        
        // When
        let calories = caloriesFromMacros(fat: f, carbohydrates: c, protein: p)
        
        // Then
        XCTAssertEqual(calories, 370, accuracy: 0.1, "Calorie calculation should be (P*4)+(C*4)+(F*9)")
    }
    
    // MARK: - Core Data Tests

    func testSaveMeal() throws {
        // Given
        let meal = MealEntity(context: context)
        meal.id = UUID()
        meal.summary = "Test Steak"
        meal.totalProtein = 50
        meal.totalCarbs = 0
        meal.totalFat = 20
        meal.timestamp = Date()
        meal.portion = 8
        meal.portionUnit = "oz"
        
        // When
        try context.save()
        
        // Then
        let request: NSFetchRequest<MealEntity> = MealEntity.fetchRequest()
        let results = try context.fetch(request)
        
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.summary, "Test Steak")
        XCTAssertEqual(results.first?.totalCalories, 380) // (50*4) + (20*9)
    }
    
    // MARK: - Service Tests (Stats)
    
    func testDailyTotals() throws {
        // Given: Two meals on the same day
        let meal1 = MealEntity(context: context)
        meal1.timestamp = Date()
        meal1.totalProtein = 10
        meal1.totalCarbs = 10
        meal1.totalFat = 10
        
        let meal2 = MealEntity(context: context)
        meal2.timestamp = Date()
        meal2.totalProtein = 5
        meal2.totalCarbs = 5
        meal2.totalFat = 5
        
        try context.save()
        
        // When: We ask for totals for today
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        
        let totals = MacroStatsService.dailyTotals(from: start, to: end, context: context)
        
        // Then
        let todayKey = start
        XCTAssertNotNil(totals[todayKey])
        XCTAssertEqual(totals[todayKey]?.protein, 15)
        XCTAssertEqual(totals[todayKey]?.carbs, 15)
        XCTAssertEqual(totals[todayKey]?.fat, 15)
    }
    
    func testAverages() throws {
        // Given: Meals on two different days
        let day1 = Date()
        let day2 = Calendar.current.date(byAdding: .day, value: -1, to: day1)!
        
        // Day 1 Meal (10, 10, 10)
        let meal1 = MealEntity(context: context)
        meal1.timestamp = day1
        meal1.totalProtein = 10
        meal1.totalCarbs = 10
        meal1.totalFat = 10
        
        // Day 2 Meal (20, 20, 20)
        let meal2 = MealEntity(context: context)
        meal2.timestamp = day2
        meal2.totalProtein = 20
        meal2.totalCarbs = 20
        meal2.totalFat = 20
        
        try context.save()
        
        // When: Calculate averages for the range covering both days
        let start = Calendar.current.startOfDay(for: day2)
        let end = Calendar.current.date(byAdding: .day, value: 2, to: start)!
        
        let average = MacroStatsService.averages(from: start, to: end, context: context)
        
        // Then: (10+20)/2 = 15
        XCTAssertEqual(average.protein, 15)
        XCTAssertEqual(average.dayCount, 2)
    }
    
    // MARK: - Model Decoding Tests
    
    func testParsedFoodIntentDecoding() throws {
        // Given: JSON similar to what Gemini returns
        let json = """
        {
            "items": [
                { "search_term": "chicken breast", "estimated_weight_grams": 200.0 },
                { "search_term": "rice", "estimated_weight_grams": 150.0 }
            ]
        }
        """.data(using: .utf8)!
        
        // When
        let result = try JSONDecoder().decode(ParsedFoodIntent.self, from: json)
        
        // Then
        XCTAssertEqual(result.items.count, 2)
        XCTAssertEqual(result.items[0].search_term, "chicken breast")
        XCTAssertEqual(result.items[0].estimated_weight_grams, 200.0)
    }
}
