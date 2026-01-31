# Macro Tracker - Architecture & Design Specification

## 1. User Requirements
The application is designed to help a user track their daily nutritional intake (macros and calories) with a focus on speed, intelligence, and offline resilience.

### Core Functionality
* **Natural Language Logging:** Users can describe meals in plain English (e.g., "3 eggs and toast") to log them.
* **Hybrid Parsing:** The system must attempt to parse inputs locally for speed (e.g., "150g Chicken") and fallback to cloud AI (Gemini) for complex descriptions.
* **Database Management:** Users need a local database of "known meals" that learns as they log, allowing for autocomplete suggestions.
* **Smart Scaling:** If a user logs a known meal with a different portion size (e.g., 120g vs. cached 60g), the system must automatically calculate the new macros based on the ratio.
* **Data Visualization:** Users must be able to view daily totals for Protein, Fat, and Carbs via bar charts.
* **Historical Navigation:** Users can swipe left/right to view stats for previous or future days.
* **Goal Tracking:** Users can set minimum and maximum targets for each macronutrient, visualized directly on the charts as "target zones."

### Input & Editing
* **"Drafting Table" UX:** Instead of instant saving, users enter a drafting mode where they can review, edit, and auto-fill data before committing to the database.
* **Live Parsing:** As the user types a description (e.g., "150g..."), the portion and unit fields must auto-populate in real-time.
* **Manual Override:** Users must be able to manually edit any auto-filled value (calories, grams, name) before saving.
* **CRUD for Cache:** Users can view, edit, and delete their saved meal database via Settings.

---

## 2. Design Requirements (UI/UX)

### Navigation Structure
The app uses a `TabView` architecture with three main tabs:
1.  **Track:** The daily log list and "Add Meal" entry point.
2.  **Stats:** Daily bar charts and history navigation.
3.  **Settings:** Configuration for goals, database management, and API keys.

### Visual Language
* **Color Coding:**
    * **Protein:** Blue
    * **Carbs:** Green
    * **Fat:** Red
* **Feedback:** "Target Zones" are rendered as shaded gray rectangles behind the macro bars. If a bar is inside the box, the user is "in the zone."
* **Hierarchy:** Meals are displayed as parent items (summary totals) with expandable detail views showing individual ingredients.

---

## 3. Architectural Decisions

No (manually managed) backend!

### Tech Stack
* **Language:** Swift 5+
* **Framework:** SwiftUI (Declarative UI)
* **Concurrency:** Swift Concurrency (`async`/`await`, `Actor` model)
* **Persistence:** Core Data with CloudKit syncing enabled.
* **Minimum OS:** iOS 16.0 (Required for Swift Charts).

### External APIs
1.  **Google Gemini (1.5 Flash):** Used for Natural Language Understanding (NLU) to convert unstructured text into structured JSON (Food Name + Estimated Weight).
2.  **USDA FoodData Central:** Used as the source of truth for nutritional data (Macros/Calories per 100g).

### Design Pattern: MVVM
The app strictly follows **Model-View-ViewModel**:
* **Models:** Core Data Entities (`MealEntity`, `FoodEntity`) and API Structs (`USDAFood`, `ParsedFoodIntent`).
* **ViewModels:** `MacroViewModel` handles business logic (API coordination, calculations) and State (`isLoading`, `errorMessage`).
* **Views:** Purely reactive UI components (`TrackerView`, `StatsView`) that observe the ViewModel.

---

## 4. Key Design Decisions

### A. The "Hybrid Parser" Strategy
To optimize for speed, battery life, and API costs, the app uses a two-tier parsing system:
1.  **Tier 1 (Local Regex):** A local heuristic parser (`LocalParser.swift`) checks for strict patterns like `[Number] [Unit] [Name]`. If found, it extracts the data instantly without network calls.
2.  **Tier 2 (Cloud Fallback):** If the input is ambiguous (e.g., "A bowl of cereal"), the app sends the query to Google Gemini to infer weights and ingredients.

### B. Smart Autocomplete & Scaling
The app implements a custom "Smart Fill" logic (`applyCachedMeal`):
* **Context Awareness:** It detects if the user has already entered a portion size.
* **Unit Matching:** It checks if the current unit matches the cached unit (e.g., grams vs. grams).
* **Ratio Logic:** If units match, it calculates `Current Portion / Cached Portion` and scales all macros by that multiplier.
* **Preset Fallback:** If units differ or input is empty, it loads the cached entry exactly as saved.

### C. Data Model Evolution (Hierarchy)
Initially, the app used a flat list of ingredients. To support "Meals" (e.g., "Breakfast"), the schema was refactored to a Parent-Child relationship:
* **Parent (`MealEntity`):** Stores the summary (e.g., "Oatmeal and Eggs"), timestamp, and aggregate macros.
* **Child (`FoodEntity`):** Stores individual components (e.g., "Oats", "Egg") linked to the parent via a "Cascade Delete" rule.

### D. Robust Error Handling
* **Defensive Decoding:** API response models use Optional types (`?`) to prevent crashes if external APIs return incomplete data (e.g., missing "foods" array from USDA).
* **Exponential Backoff:** The network layer includes logic to handle `429 Rate Limit` errors by waiting and retrying requests automatically.

### E. Debugging Infrastructure
To facilitate on-device debugging without a computer connection, a custom Logging System was built:
* **Actor-Based:** Uses an `actor LogStore` to ensure thread-safe writing to a text file.
* **Exportable:** A `LogViewer` screen allows the user to view logs and export them via the native iOS Share Sheet (AirDrop/Files).

---

## 5. Core Data Schema

### Entity: `MealEntity`
* **Attributes:** `id` (UUID), `timestamp` (Date), `summary` (String), `totalCalories` (Double), `totalProtein` (Double), `totalFat` (Double), `totalCarbs` (Double).
* **Relationships:** `ingredients` (To-Many relationship to `FoodEntity`).

### Entity: `FoodEntity`
* **Attributes:** `name` (String), `weightGrams` (Double), `calories` (Double), `protein` (Double), `fat` (Double), `carbs` (Double).
* **Relationships:** `meal` (To-One relationship to `MealEntity`).

### Entity: `CachedMealEntity`
* **Purpose:** Stores "learned" meals for autocomplete.
* **Attributes:** `name` (String), `portionSize` (String), `unit` (String), `calories` (Double), `protein` (Double), `fat` (Double), `carbs` (Double), `lastUsed` (Date).
