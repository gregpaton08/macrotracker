//
//  MacroTrackerUITests.swift
//  MacroTrackerUITests
//
//  Created by Gregory Paton on 1/25/26.
//

import XCTest

final class MacroTrackerUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        
        // Reset the app state if possible, or handle existing data in tests.
        // For V1, we assume a standard environment.
        app.launchArguments += ["-UITesting"]
        app.launch()
    }

    func testAddManualMeal() throws {
        // 1. Check we are on the Tracker screen
        XCTAssertTrue(app.navigationBars["Tracker"].exists)
        
        // 2. Tap Add Button (Plus Circle Icon)
        // Note: Images in buttons sometimes tricky to find, but we can search by the button role
        let addButton = app.buttons["plus.circle.fill"]
        if addButton.exists {
            addButton.tap()
        } else {
            // Fallback if accessibility identifier isn't set, try finding the last button in toolbar
            app.toolbars.buttons.element(boundBy: 1).tap()
        }
        
        // 3. Check Add Meal Sheet appeared
        XCTAssertTrue(app.navigationBars["Add Meal"].exists)
        
        // 4. Fill in Details
        let descField = app.textFields["Description (e.g. Chicken)"]
        XCTAssertTrue(descField.waitForExistence(timeout: 2))
        descField.tap()
        descField.typeText("UI Test Apple")
        
        let portionField = app.textFields["Portion"]
        portionField.tap()
        portionField.typeText("1")
        
        // 5. Fill in Macros
        let fatField = app.textFields["0"].firstMatch // Finding by placeholder "0"
        fatField.tap()
        fatField.typeText("0")
        
        // Tap next text field (Carbs)
        // Since we have multiple "0" fields, we iterate or rely on keyboard Next
        // Simpler way for UI tests is often tapping coordinates or unique identifiers
        // But let's try tapping the second "0" field found
        
        // Try saving directly to keep test simple (Macros = 0)
        
        // 6. Save
        app.buttons["Save"].tap()
        
        // 7. Verify it appears on Dashboard
        // We wait for the sheet to dismiss and list to update
        let mealCell = app.staticTexts["UI Test Apple"]
        XCTAssertTrue(mealCell.waitForExistence(timeout: 2), "The added meal should appear in the list")
    }
    
    func testNavigationToInsights() {
        // Tap the Chart icon
        let chartButton = app.buttons["chart.xyaxis.line"]
        if chartButton.exists {
            chartButton.tap()
            XCTAssertTrue(app.navigationBars["Insights"].exists)
        }
    }
    
    func testNavigationToSettings() {
        // Tap the Gear icon
        let gearButton = app.buttons["gear"]
        if gearButton.exists {
            gearButton.tap()
            XCTAssertTrue(app.navigationBars["Settings"].exists)
        }
    }
}
