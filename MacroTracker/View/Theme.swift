//
//  Theme.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/8/26.
//

import SwiftUI

struct Theme {
    static let tint = Color.blue
    static let background = Color(uiColor: .systemGroupedBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemGroupedBackground)
    
    // Status Colors
    static let good = Color.green
    static let under = Color.yellow
    static let over = Color.red
    static let neutral = Color.gray.opacity(0.3)
    
    // Logic for determining color based on goals
    static func statusColor(value: Double, min: Double, max: Double) -> Color {
        if value < min { return .yellow } // Under
        if value > max { return .red }    // Over
        return .green                     // Good
    }
}
