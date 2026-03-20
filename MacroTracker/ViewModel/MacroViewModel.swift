//
//  MacroViewModel.swift
//  MacroTracker
//
//  Central orchestrator for meal logging.
//  Coordinates Gemini API calls, macro calculation, nutrition-label
//  scanning, and CoreData writes.
//

import CoreData
import OSLog
import SwiftUI
import UIKit

@MainActor
class MacroViewModel: ObservableObject {
    let context: NSManagedObjectContext
    private let logger = Logger(subsystem: "com.macrotracker", category: "ViewModel")

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showError = false

    private var geminiClient: GeminiClient?

    init(context: NSManagedObjectContext) {
        self.context = context
        setupClient()
    }

    /// (Re)creates the Gemini client from the current UserDefaults API key.
    /// Called on init and before each API request so key changes take effect immediately.
    private func setupClient() {
        let defaults = UserDefaults.standard
        guard let googleKey = defaults.string(forKey: "google_api_key"), !googleKey.isEmpty else {
            return
        }
        let model = defaults.string(forKey: "gemini_model") ?? "gemini-2.0-flash"
        self.geminiClient = GeminiClient(apiKey: googleKey, model: model)
    }

    // MARK: - AI Macro Analysis

    /// Sends a food description to Gemini and returns estimated macros in one round-trip.
    func calculateMacros(description: String) async -> (p: Double, c: Double, f: Double, k: Double)?
    {
        setupClient()

        guard let gemini = geminiClient else {
            errorMessage = "Google API Key missing. Please check Settings."
            showError = true
            return nil
        }

        isLoading = true
        defer { isLoading = false }

        do {
            // SINGLE CALL - Much faster
            let result = try await gemini.analyzeFood(userText: description)

            return (
                result.total_protein,
                result.total_carbs,
                result.total_fat,
                result.total_calories
            )

        } catch is CancellationError {
            return nil
        } catch {
            logger.error("AI Analysis Failed: \(error.localizedDescription)")
            errorMessage = "Could not analyze food. Please try again. \(error.localizedDescription)"
            showError = true
            return nil
        }
    }

    /// Sends a free-text meal description to Gemini and returns the full
    /// `AIAnalysisResult`, including the per-item breakdown used by `DescribeMealView`.
    func analyzeDescription(text: String) async -> AIAnalysisResult? {
        setupClient()

        guard let gemini = geminiClient else {
            errorMessage = "Google API Key missing. Please check Settings."
            showError = true
            return nil
        }

        isLoading = true
        defer { isLoading = false }

        do {
            return try await gemini.analyzeFood(userText: text)
        } catch is CancellationError {
            return nil
        } catch {
            logger.error("AI description analysis failed: \(error.localizedDescription)")
            errorMessage = "Could not analyze food. \(error.localizedDescription)"
            showError = true
            return nil
        }
    }

    // MARK: - Nutrition Label Scanning

    /// Sends a photo of a nutrition facts label to Gemini Vision and returns
    /// the extracted macro values. Returns `nil` on failure (error is shown via alert).
    func scanNutritionLabel(image: UIImage) async -> ParsedNutritionLabel? {
        setupClient()

        guard let gemini = geminiClient else {
            errorMessage = "Gemini API Key missing. Please add it in Settings."
            showError = true
            return nil
        }

        isLoading = true
        defer { isLoading = false }

        do {
            return try await gemini.parseNutritionLabel(image: image)
        } catch is CancellationError {
            return nil
        } catch {
            logger.error("Label scan failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
            return nil
        }
    }

    // MARK: - Recipe Scanning

    /// Sends a photo of a cookbook recipe to Gemini Vision and returns
    /// estimated per-serving macros. Returns `nil` on failure (error is shown via alert).
    func scanRecipe(image: UIImage) async -> ParsedNutritionLabel? {
        setupClient()

        guard let gemini = geminiClient else {
            errorMessage = "Gemini API Key missing. Please add it in Settings."
            showError = true
            return nil
        }

        isLoading = true
        defer { isLoading = false }

        do {
            return try await gemini.parseRecipe(image: image)
        } catch is CancellationError {
            return nil
        } catch {
            logger.error("Recipe scan failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            showError = true
            return nil
        }
    }

    // MARK: - Persistence

    /// Creates and saves a new `MealEntity`. Returns `true` on success.
    /// The timestamp combines the target `date` with the current wall-clock time.
    @discardableResult
    func saveMeal(
        description: String, p: Double, f: Double, c: Double, portion: Double, portionUnit: String,
        date: Date
    ) -> Bool {
        let newMeal = MealEntity(context: context)
        newMeal.id = UUID()
        newMeal.timestamp = combineDate(date, withTime: Date())
        newMeal.summary = description
        newMeal.totalProtein = p
        newMeal.totalFat = f
        newMeal.totalCarbs = c
        newMeal.portion = portion
        newMeal.portionUnit = portionUnit

        do {
            try context.save()
            return true
        } catch {
            context.rollback()
            errorMessage = "Failed to save meal."
            showError = true
            return false
        }
    }

    /// Merges the year/month/day from `date` with the hour/minute/second from `time`.
    private func combineDate(_ date: Date, withTime time: Date) -> Date {
        let calendar = Calendar.current
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: time)
        return calendar.date(
            from: DateComponents(
                year: dateComponents.year, month: dateComponents.month, day: dateComponents.day,
                hour: timeComponents.hour, minute: timeComponents.minute,
                second: timeComponents.second))
            ?? date
    }

    // MARK: - Background Analysis

    /// Fetches macros without triggering the global isLoading or showError UI overlays.
    private func fetchMacrosQuietly(description: String) async -> (p: Double, c: Double, f: Double, k: Double)? {
        setupClient()
        guard let gemini = geminiClient else { return nil }
        do {
            let result = try await gemini.analyzeFood(userText: description)
            return (result.total_protein, result.total_carbs, result.total_fat, result.total_calories)
        } catch {
            return nil
        }
    }

    /// Immediately saves a placeholder meal and spawns a detached task to fetch macros.
    func saveAndAnalyzeInBackground(description: String, portion: String, unit: String, date: Date) {
        let newMeal = MealEntity(context: context)
        newMeal.id = UUID()
        newMeal.timestamp = combineDate(date, withTime: Date())
        newMeal.summary = description
        newMeal.portion = Double(portion) ?? 0
        newMeal.portionUnit = unit
        newMeal.processingState = .pending // Flag it as loading
        
        try? context.save()
        
        let objectID = newMeal.objectID // Thread-safe reference for the background task
        let query = portion.isEmpty ? description : "\(portion) \(unit) \(description)"
        
        Task {
            let result = await self.fetchMacrosQuietly(description: query)
            
            await MainActor.run {
                // Re-fetch the object on the main thread
                guard let savedMeal = try? self.context.existingObject(with: objectID) as? MealEntity else { return }
                
                if let res = result {
                    savedMeal.totalProtein = res.p
                    savedMeal.totalCarbs = res.c
                    savedMeal.totalFat = res.f
                    savedMeal.processingState = .completed
                    
                    MealCacheManager.shared.cacheMeal(
                        name: description, p: res.p, f: res.f, c: res.c,
                        portion: portion, unit: unit
                    )
                } else {
                    savedMeal.processingState = .failed
                }
                try? self.context.save()
            }
        }
    }

    /// Retries a failed background analysis.
    func retryAnalysis(for meal: MealEntity) {
        guard let summary = meal.summary else { return }
        meal.processingState = .pending
        try? context.save()
        
        let portion = meal.portion > 0 ? String(meal.portion) : ""
        let unit = meal.portionUnit ?? ""
        let query = portion.isEmpty ? summary : "\(portion) \(unit) \(summary)"
        let objectID = meal.objectID
        
        Task {
            let result = await self.fetchMacrosQuietly(description: query)
            await MainActor.run {
                guard let savedMeal = try? self.context.existingObject(with: objectID) as? MealEntity else { return }
                if let res = result {
                    savedMeal.totalProtein = res.p
                    savedMeal.totalCarbs = res.c
                    savedMeal.totalFat = res.f
                    savedMeal.processingState = .completed
                } else {
                    savedMeal.processingState = .failed
                }
                try? self.context.save()
            }
        }
    }
}
