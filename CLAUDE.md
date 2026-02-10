# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

MacroTracker is a native iOS app (iOS 16.0+) for tracking daily macronutrient intake. It prioritizes simplicity and ease of use over high accuracy. Users log meals via natural language, and the app estimates macros using Google Gemini for parsing and the USDA Food Data Central API for nutritional data.

## Build & Run

This is a standard Xcode project with no external package dependencies (no SPM, CocoaPods, or Carthage).

```bash
# Build
xcodebuild build -project MacroTracker.xcodeproj -scheme MacroTracker -destination 'platform=iOS Simulator,name=iPhone 16'

# Run tests (test target exists but has no real tests yet)
xcodebuild test -project MacroTracker.xcodeproj -scheme MacroTracker -destination 'platform=iOS Simulator,name=iPhone 16'
```

No linter is configured.

## Architecture

**Pattern:** MVVM with a service layer.

**Data flow for meal logging:**
```
User text input → LocalParser (regex, instant)
                 ↘ fallback: Gemini API (NLU → structured JSON)
                   → USDA API (nutrition per 100g)
                     → aggregate macros → save MealEntity to CoreData
```

- `MacroViewModel` is the central orchestrator — it coordinates API calls, macro calculation, and CoreData writes.
- Views observe `MacroViewModel` via `@ObservedObject`.
- `LocalParser` provides a fast regex-based tier that avoids API calls for simple inputs like "200g chicken breast".

**Persistence:** CoreData with `NSPersistentCloudKitContainer` for automatic iCloud sync. Auto-migration is enabled. Merge policy is "property object trump" (local wins on conflict).

**Key services:**
- `GeminiClient` — sends meal descriptions to Gemini, receives structured food items with estimated weights.
- `USDAClient` — queries USDA FDC for macros per 100g.
- `MealCacheManager` — CRUD for `CachedMealEntity`, which powers smart autocomplete and portion scaling.
- `HealthManager` — reads active energy and workouts from HealthKit.

**CoreData entities:**
- `MealEntity` — a logged meal with summary text and total macros. `totalCalories` is computed (P×4 + C×4 + F×9).
- `CachedMealEntity` — reusable meal templates for autocomplete; stores portion size/unit and macros, scales by ratio when portion differs.

**Date navigation:** `TrackerView` uses a `TabView` with a 730-day range (±365 from today). `LazyView` defers page computation until visible.

## API Keys

Users configure two API keys in-app via SettingsView, stored in UserDefaults:
- `"google_api_key"` — Google Gemini
- `"usda_api_key"` — USDA Food Data Central

## Entitlements

CloudKit and HealthKit are enabled. The app reads active energy burned and workout data from HealthKit.

## TODO directives

If you see a comment containing TODO be sure to keep it in the code. Do not remove it when rewriting code.
