//
//  ProgressRings.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/5/26.
//
//  Circular progress ring that visualizes a macro value against a
//  min/max goal range. Three visual states:
//    - Under (yellow): value < min
//    - Good  (green):  min ≤ value ≤ max
//    - Over  (red):    value > max — shows a full red ring plus an
//      overflow arc indicating how far past the limit.
//

import Foundation
import SwiftUI

// MARK: - Progress Ring

struct ProgressRing: View {
  let label: String
  let value: Double
  let min: Double
  let max: Double

  /// Guards against NaN / Infinity so the ring never renders garbage.
  private func sanitize(_ val: Double) -> Double {
    if val.isNaN || val.isInfinite { return 0.0 }
    return val
  }

  /// Max goal, clamped to at least 100 to avoid divide-by-zero.
  var safeMax: Double {
    let m = sanitize(max)
    return m > 0 ? m : 100
  }

  /// Fraction of the ring where the "goal zone" arc begins (min / max).
  var minFraction: CGFloat {
    let val = sanitize(min) / safeMax
    return CGFloat(sanitize(val))
  }

  /// Current value as a fraction of max (0.0 – 1.0+).
  var currentFraction: CGFloat {
    let val = sanitize(value) / safeMax
    return CGFloat(sanitize(val))
  }

  /// Overflow arc fraction (> 0 only when value exceeds max).
  /// Uses modulo to handle lapping multiple times.
  var overflowFraction: CGFloat {
    let fraction = currentFraction
    if fraction > 1.0 {
      return fraction.truncatingRemainder(dividingBy: 1.0)
    }
    return 0.0
  }

  /// Determines the visual state based on value vs. goal range.
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
            .foregroundColor(Color(red: 0.6, green: 0, blue: 0))  // Dark Blood Red
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

// MARK: - Ring State

/// Visual state of a progress ring relative to the user's goal range.
enum RingState {
  case under, good, over

  var color: Color {
    switch self {
    case .under: return Theme.under
    case .good: return Theme.good
    case .over: return Theme.over
    }
  }

  var icon: String? {
    switch self {
    case .under: return nil  // Or use "arrow.up" to indicate "eat more"
    case .good: return "checkmark"
    case .over: return "xmark.octagon.fill"
    }
  }
}
