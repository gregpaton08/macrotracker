//
//  LocalParser.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/30/26.
//

import Foundation

struct LocalParser {
    
    struct ParsedResult {
        let qty: Double
        let unit: String?
        let foodName: String
    }
    
    // Regex explanation:
    // ^                  Start of string
    // (\d+(?:\.\d+)?)    Capture Group 1: Number (integer or decimal)
    // \s* Allow spaces (or no spaces)
    // ([a-zA-Z]+)?       Capture Group 2: Unit (Optional, text only)
    // \s+                Required space separator
    // (.*)               Capture Group 3: The rest (Food Name)
    // $                  End of string
    static let pattern = #"^(\d+(?:\.\d+)?)\s*([a-zA-Z]+)?\s+(.*)$"#
    
    static func parse(_ input: String) -> ParsedResult? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Handle "an apple" or "a banana" edge cases manually if you want
        if trimmed.starts(with: "a ") || trimmed.starts(with: "an ") {
            return nil // Let the Cloud LLM handle "a/an" logic
        }
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        
        guard let match = regex.firstMatch(in: trimmed, options: [], range: range) else {
            return nil
        }
        
        // Extract Quantity
        guard let qtyRange = Range(match.range(at: 1), in: trimmed),
              let qty = Double(trimmed[qtyRange]) else { return nil }
        
        // Extract Unit (Optional)
        var unit: String? = nil
        if let unitRange = Range(match.range(at: 2), in: trimmed) {
            unit = String(trimmed[unitRange])
            // Filter out if the unit is actually part of the food name (heuristic guess)
            // e.g. "3 eggs" -> "eggs" might be caught as unit if we aren't careful.
            // A simple check: Common units list.
            if !isValidUnit(unit!) {
                return nil // Fallback to cloud if we aren't sure
            }
        }
        
        // Extract Food Name
        guard let foodRange = Range(match.range(at: 3), in: trimmed) else { return nil }
        let food = String(trimmed[foodRange])
        
        return ParsedResult(qty: qty, unit: unit, foodName: food)
    }
    
    // Whitelist common units to avoid false positives
    static func isValidUnit(_ u: String) -> Bool {
        let commonUnits = ["g", "gram", "grams", "oz", "ounce", "ounces", "lb", "lbs", "cup", "cups", "ml", "l", "tbsp", "tsp"]
        return commonUnits.contains(u)
    }
}
