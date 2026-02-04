#  MacroTracker (working title)

## Design Goals and Motivation

I want a dead simple way to track my macros. I'm prioritizing ease of use over high accuracy.

## TODO

### V1

* Handle data migrations when data model changes
* Export backups and load from backup
* Flesh out data model fully
* Calories should be computed from macros

### Backlog

* Add a logging framework
* Add tests
* Weekly and monthly calenda
* Daily notes

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

```bash
cargo install code2prompt --version 3.0.2 # `source_tree` is broken in latest

code2prompt . --template project.hbs --output-file context.md

code2prompt . \
  --template project.hbs \
  --include "*.swift,*.plist,*.json,*.entitlements" \
  --exclude "**/DerivedData/**,**/Pods/**,**/Carthage/**,**/.build/**,**/fastlane/**,**/*.xcodeproj/**,**/*.xcworkspace/**,**.md**,**.hbs**" \
  --output-file project_context.md
```
