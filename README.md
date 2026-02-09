#  MacroTracker (working title)

## Design Goals and Motivation

I want a dead simple way to track my macros. I'm prioritizing ease of use over high accuracy.

## TODO

### V1

* Export backups and load from backup
* Flesh out data model fully

### Backlog

* Add a logging framework
* Add tests
* Weekly and monthly calendar
* Daily notes
* Handle data migrations when data model changes

## APIs

https://fdc.nal.usda.gov/api-guide
https://app.swaggerhub.com/apis/fdcnal/food-data_central_api/1.0.1#/FDC/getFoodsSearch

```bash
curl -s "https://generativelanguage.googleapis.com/v1beta/models?key=${GEMINI_API_KEY}" | grep "name" | sort

curl -s "https://api.nal.usda.gov/fdc/v1/foods/search?query=honey&dataType=Foundation,SR%20Legacy&pageSize=1&api_key=$USDA_API_KEY" | jq '.foods[]' | select(any(.foodNutrients[]; .nutrientName == "Protein"))'

curl -s "https://api.nal.usda.gov/fdc/v1/foods/search?query=honey&dataType=Foundation,SR%20Legacy&pageSize=1&api_key=$USDA_API_KEY" | jq '.foods[].foodNutrients[] | select(.nutrientName == "Protein" or .nutrientName == "Carbohydrate, by difference" or .nutrientName == "Total lipid (fat)")'
```

## Prompts

half an omelette with bacon and american cheese from a diner

A chicken and cheese quesadilla with a lot of chicken. The entire thing weighed 685 grams

10 cocktail weenies. The sauce is bbq sauce and grape jelly.

Bow tie pasta in pesto with zucchini, corn, and mozzarella


Analyze this food log: "half an omelette with bacon and american cheese from a diner".
Return ONLY valid JSON. Do not use Markdown formatting.
Schema:
{ "items": [ { "search_term": "string (USDA database optimized)", "estimated_weight_grams": number } ] }


Analyze this food log: "strawberry cheesecake ice cream concrete".
Return ONLY valid JSON. Do not use Markdown formatting.
Schema:
{ "items": [ { "search_term": "string (USDA database optimized)", "estimated_weight_grams": number } ] }

## Code dump for LLM

Gemini 3 Pro claims to 1M token context window size.

[Sample templates](https://github.com/mufeedvh/code2prompt/tree/main/crates/code2prompt-core/templates).

```bash
cargo install code2prompt --version 3.0.2 # `source_tree` is broken in latest

code2prompt . --template project.hbs --output-file context.md

code2prompt . \
  --template project.hbs \
  --include "*.swift,*.plist,*.json,*.entitlements" \
  --exclude "**/DerivedData/**,**/Pods/**,**/Carthage/**,**/.build/**,**/fastlane/**,**/*.xcodeproj/**,**/*.xcworkspace/**,**.md**,**.hbs**" \
  --output-file project_context.md
```

## Random

```Here's an honest assessment — the app works well on the happy path, but it's not quite v1 ready. The biggest theme is silent failures: when things go wrong, the user sees zeros or empty screens with no explanation.

  Must-fix before release

  1. Errors are invisible to users. MacroViewModel.errorMessage is set on API failures but no view ever displays it. When Gemini is rate-limited (429), the app silently returns 0 for all macros. The user thinks their food has no calories.

  2. CoreData failures are silently swallowed. If loadPersistentStores fails (Persistence.swift:31), the app launches with an empty, non-functional state — looks like total data loss. Every try? viewContext.save() throughout the codebase
  also discards errors silently.

  3. Gemini error parsing is broken. In GeminiClient.swift:74-83, the inner catch catches both JSON decode failures and the intentional throw URLError on the line above, so the meaningful error message from the API is always lost and
  replaced with a generic one.

  4. LocalParser is dead code. It exists but is never called anywhere — the hybrid parsing tier described in the architecture isn't wired up.

  Should-fix

  - API keys in UserDefaults — not encrypted, included in unencrypted backups. Keychain is the standard for secrets.
  - Logger subsystems — two of three use the placeholder "com.yourdomain.yourapp".
  - Typo in Gemini prompt — "earching" instead of "searching" (GeminiClient.swift:47).
  - useDummyData = false flag left in production code (GeminiClient.swift:19).
  - No cancel/timeout on AI analysis — user is stuck if the network hangs.
  - Deprecated APIs — NavigationView in sheets (use NavigationStack), presentationMode (use dismiss), onChange single-parameter form.
  - combineSources toggle — tapping "Burned" label secretly changes the calculation mode with no explanation.
  - Meals with 0 macros get cached — failed API calls create useless saved meal entries.

  Nice-to-have

  - Clean up commented-out code (old Logger calls scattered throughout).
  - Input validation on macro goal ranges (min > max is allowed).
  - HealthManager.requestAuthorization() called on every DailyDashboard appear — wasteful.
  - RingState.icon property is defined but never used.

  ---
  The core meal tracking flow is solid and the architecture is clean. I'd prioritize making errors visible (wire up errorMessage, show alerts on save failures) and fixing the Gemini error handling bug — those are the difference between
  "it broke and I don't know why" and a usable v1.

  Want me to tackle any of these?
```