//
//  AveragesMacroView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/8/26.
//
//  Displays average daily macros using the existing ProgressRing component,
//  plus a numeric summary row. Shown inside InsightsView.
//

import SwiftUI

/// Card component that visualizes average daily macros as progress rings
/// and a compact numeric row (Avg Cal / Fat / Carbs / Protein).
struct AveragesMacroView: View {
    let averages: MacroAverage

    // Goal ranges (passed in from InsightsView)
    let pMin: Double, pMax: Double
    let cMin: Double, cMax: Double
    let fMin: Double, fMax: Double

    var body: some View {
        VStack(spacing: 16) {
            // Reuse existing ProgressRing component for visual consistency
            HStack(spacing: 15) {
                ProgressRing(label: "Fat", value: averages.fat, min: fMin, max: fMax)
                ProgressRing(label: "Carbs", value: averages.carbs, min: cMin, max: cMax)
                ProgressRing(label: "Protein", value: averages.protein, min: pMin, max: pMax)
            }
            .padding(.horizontal, 20)

            // Numeric summary
            HStack(spacing: 0) {
                macroStat(label: "Avg Cal", value: "\(Int(averages.calories))")
                Spacer()
                macroStat(label: "Avg Fat", value: "\(Int(averages.fat))g")
                Spacer()
                macroStat(label: "Avg Carbs", value: "\(Int(averages.carbs))g")
                Spacer()
                macroStat(label: "Avg Protein", value: "\(Int(averages.protein))g")
            }
            .padding(.horizontal, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    /// Small vertical stat column (value on top, label below).
    private func macroStat(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline)
                .bold()
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}
