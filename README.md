#  MacroTracker (working title)

## Design Goals and Motivation

I want a dead simple way to track my macros. I'm prioritizing ease of use over high accuracy and precision.

## TODO

* Add a logging framework
* Add tests

## APIs

```bash
curl -s "https://generativelanguage.googleapis.com/v1beta/models?key=${GEMINI_API_KEY}" | grep "name" | sort

curl -s "https://api.nal.usda.gov/fdc/v1/foods/search?query=honey&dataType=Foundation,SR%20Legacy&pageSize=1&api_key=$USDA_API_KEY" | jq '.foods[]' | select(any(.foodNutrients[]; .nutrientName == "Protein"))'

curl -s "https://api.nal.usda.gov/fdc/v1/foods/search?query=honey&dataType=Foundation,SR%20Legacy&pageSize=1&api_key=$USDA_API_KEY" | jq '.foods[].foodNutrients[] | select(.nutrientName == "Protein" or .nutrientName == "Carbohydrate, by difference" or .nutrientName == "Total lipid (fat)")'
```
