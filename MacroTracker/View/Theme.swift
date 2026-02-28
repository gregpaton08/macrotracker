//
//  Theme.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/8/26.
//
//  Centralized color constants for the app. All views reference
//  these values so the palette can be adjusted in one place.
//

import SwiftUI

struct Theme {
    // MARK: - Brand

    static let tint = Color.blue

    // MARK: - Backgrounds

    static let background = Color(uiColor: .systemGroupedBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemGroupedBackground)

    // MARK: - Goal Status Colors

    static let good = Color.green  // Value is within goal range
    static let under = Color.yellow  // Value is below minimum
    static let over = Color.red  // Value exceeds maximum
    static let neutral = Color.gray.opacity(0.3)

    /// Returns the appropriate status color for a macro value vs. its goal range.
    static func statusColor(value: Double, min: Double, max: Double) -> Color {
        if value < min { return under }
        if value > max { return over }
        return good
    }
}
