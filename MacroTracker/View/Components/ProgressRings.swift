//
//  ProgressRings.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/5/26.
//

import Foundation
import SwiftUI

// MARK: - The Custom Ring Component
struct ProgressRing: View {
    let label: String
    let value: Double
    let min: Double
    let max: Double

    // 1. Math Helpers
    private func sanitize(_ val: Double) -> Double {
        if val.isNaN || val.isInfinite { return 0.0 }
        return val
    }

    var safeMax: Double {
        let m = sanitize(max)
        return m > 0 ? m : 100
    }

    // The "Goal Zone" arc (Min to Max)
    var minFraction: CGFloat {
        let val = sanitize(min) / safeMax
        return CGFloat(sanitize(val))
    }

    // Standard Progress (0.0 to 1.0)
    var currentFraction: CGFloat {
        let val = sanitize(value) / safeMax
        return CGFloat(sanitize(val))
    }

    // Overflow Logic (How much past 100% are we?)
    // Uses modulo to handle lapping multiple times if needed
    var overflowFraction: CGFloat {
        let fraction = currentFraction
        if fraction > 1.0 {
            return fraction.truncatingRemainder(dividingBy: 1.0)
        }
        return 0.0
    }

    var state: RingState {
        let val = sanitize(value)
        if val < sanitize(min) { return .under }
        if val > sanitize(max) { return .over }
        return .good
    }

    var body: some View {
        VStack {
            ZStack {
                // 1. Base Track (Gray)
                Circle()
                    .stroke(lineWidth: 8)
                    .opacity(0.1)
                    .foregroundColor(.primary)

                // 2. Target Zone (Green Arc)
                // We keep this visible so you can see where the "safe zone" was
                Circle()
                    .trim(from: minFraction, to: 1.0)
                    .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                    .rotationEffect(Angle(degrees: 270.0))
                    .opacity(0.15)
                    .foregroundColor(.green)

                // 3. MAIN PROGRESS RING
                if state == .over {
                    // CASE A: OVER LIMIT
                    // Layer 1: Full Circle (Base Red) represents the Max Limit
                    Circle()
                        .stroke(lineWidth: 8)
                        .foregroundColor(.red)
                        .opacity(0.8)

                    // Layer 2: The Overflow (Darker/Distinct Red)
                    // Wraps around to show how far over you are
                    Circle()
                        .trim(from: 0.0, to: overflowFraction)
                        .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                        .rotationEffect(Angle(degrees: 270.0))
                        .foregroundColor(Color(red: 0.6, green: 0, blue: 0)) // Dark Blood Red
                } else {
                    // CASE B: NORMAL PROGRESS
                    Circle()
                        .trim(from: 0.0, to: currentFraction)
                        .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                        .foregroundColor(state.color)
                        .rotationEffect(Angle(degrees: 270.0))
                        .animation(.spring(), value: value)
                }

                // 4. CENTER CONTENT
                VStack(spacing: 2) {
                    Text("\(Int(sanitize(value)))g")
                        .font(.headline)
                        .bold()
                        .minimumScaleFactor(0.6)

                    if state == .over {
                        // FIX: Show "Stop" + Amount Over
                        HStack(spacing: 2) {
                            Image(systemName: "xmark.octagon.fill")
                            Text("+\(Int(sanitize(value) - sanitize(max)))")
                        }
                        .foregroundColor(.red)
                        .font(.system(size: 10, weight: .bold))
                        .minimumScaleFactor(0.8)

                    } else if state == .good {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.subheadline)
                    } else {
                        // Range
                        Text("\(Int(sanitize(min)))-\(Int(sanitize(max)))")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .minimumScaleFactor(0.8)
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)

            Text(label)
                .font(.caption)
                .bold()
                .padding(.top, 5)
                .minimumScaleFactor(0.8)
        }
    }
}

enum RingState {
    case under, good, over

    var color: Color {
        switch self {
        case .under: return .yellow
        case .good: return .green
        case .over: return .red
        }
    }

    var icon: String? {
        switch self {
        case .under: return nil // Or use "arrow.up" to indicate "eat more"
        case .good: return "checkmark"
        case .over: return "xmark.octagon.fill"
        }
    }
}
