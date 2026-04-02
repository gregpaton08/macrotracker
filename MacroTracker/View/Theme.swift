//
//  Theme.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/8/26.
//
//  Centralized color constants and goal-status logic for the app.
//  All views reference these values so the palette and comparison
//  rules (like tolerances) can be adjusted in one place.
//

import SwiftUI

// MARK: - Goal Status

/// Visual state of a macro value relative to its user-defined goal range.
enum GoalStatus {
    case under
    case good
    case over

    /// Computes the status for a given value against a min/max range.
    /// Includes a small 0.1g tolerance to handle floating point noise
    /// and ensure hitting the exact limit displays as "good".
    static func status(for value: Double, min: Double, max: Double) -> GoalStatus {
        if value < (min - 0.1) {
            return .under
        } else if value.rounded(.down) > max {
            return .over
        } else {
            return .good
        }
    }

    var color: Color {
        switch self {
        case .under: return Theme.under
        case .good:  return Theme.good
        case .over:  return Theme.over
        }
    }

    var icon: String? {
        switch self {
        case .under: return nil
        case .good:  return "checkmark.circle.fill"
        case .over:  return "xmark.octagon.fill"
        }
    }
}

// MARK: - Theme

struct Theme {
    // MARK: - Brand

    static let tint = Color.blue

    // MARK: - Backgrounds

    static let background = Color(uiColor: .systemGroupedBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemGroupedBackground)

    // MARK: - Goal Status Colors

    static let good = Color.green    // Value is within goal range
    static let under = Color.yellow  // Value is below minimum
    static let over = Color.red      // Value exceeds maximum
    static let neutral = Color.gray.opacity(0.3)

    /// Returns the appropriate status color for a macro value vs. its goal range.
    static func statusColor(value: Double, min: Double, max: Double) -> Color {
        GoalStatus.status(for: value, min: min, max: max).color
    }
}
