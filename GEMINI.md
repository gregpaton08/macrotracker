# MacroTracker

MacroTracker is a native iOS application (iOS 16.0+) designed for "dead simple" macronutrient tracking. It prioritizes ease of use and speed over high accuracy, leveraging natural language processing to convert meal descriptions into structured nutritional data.

## Project Overview

- **Core Functionality:** Natural language meal logging, hybrid parsing (local regex + Gemini AI fallback), smart portion scaling, and data visualization via Swift Charts.
- **Key Technologies:**
  - **Frameworks:** SwiftUI, Core Data (with CloudKit sync), HealthKit (for active energy and workouts), Swift Concurrency.
  - **AI/ML:** Google Gemini (1.5 Flash/Pro) for NLU, OCR (nutrition labels and recipes), and food weight estimation.
  - **Data Sources:** USDA FoodData Central for nutritional information.
- **Architecture:** MVVM (Model-View-ViewModel) with a dedicated service layer for API coordination and data management.

## Building and Running

The project is a standard Xcode project but includes a `Makefile` for streamlined development tasks.

### Prerequisites
- macOS with Xcode installed.
- iOS 16.0+ SDK.
- `swift-format` and `swiftlint` (optional, for formatting/linting).

### Key Commands

```bash
# Build the app (Debug configuration)
make build

# Run unit tests
make test

# Run UI tests
make test-ui

# Format code (uses xcrun swift format)
make fmt

# Lint code (requires swiftlint)
make lint

# Clean build artifacts
make clean

# Install on a connected physical device
make install
```

### Configuration
- **API Keys:** Users must provide their own Google Gemini API key via the in-app Settings view. This is stored in `UserDefaults` under the key `"google_api_key"`.
- **Gemini Model:** Configurable in settings (`"gemini_model"`), defaults to `gemini-2.0-flash`.

## Development Conventions

- **Architecture Pattern:** Strictly follow MVVM. 
  - `MacroViewModel` is the central orchestrator for business logic, coordinating between views and services (`GeminiClient`, `MealCacheManager`, `HealthManager`).
  - Views should be reactive and observe the ViewModel.
- **Persistence:** 
  - Use Core Data with `NSPersistentCloudKitContainer` for automatic iCloud synchronization.
  - Entities: `MealEntity` (logged meals), `CachedMealEntity` (templates for autocomplete/scaling).
  - Merge Policy: "Property Object Trump" (local changes typically win on conflict).
- **Coding Style:**
  - Adhere to the formatting rules defined in `.swift-format`.
  - Use `make fmt` before committing changes.
  - Maintain existing logging patterns using `OSLog` (subsystem: `com.macrotracker`).
- **Error Handling:**
  - Errors should be propagated to the UI via the ViewModel's `errorMessage` and `showError` properties.
  - Avoid silent failures; ensure `try?` is only used when the result is truly optional or failure is expected and handled.
- **Testing:**
  - Add unit tests for new logic in `MacroTrackerTests`.
  - UI tests should be added to `MacroTrackerUITests` for critical user flows.
- **Natural Language Parsing Tier:**
  1. **Tier 1 (Local):** `LocalParser.swift` (Regex-based) for instant results.
  2. **Tier 2 (AI):** `GeminiClient.swift` for complex NLU tasks.

## Key Files & Directories

- `MacroTracker/App/`: Entry point and app-level configuration.
- `MacroTracker/ViewModel/`: Central business logic (`MacroViewModel`).
- `MacroTracker/Service/`: API clients, HealthKit integration, and data managers.
- `MacroTracker/View/`: SwiftUI components and screen layouts.
- `MacroTracker/Model/`: Core Data extensions and API response models.
- `MacroTracker.xcdatamodel`: The project's Core Data schema.
