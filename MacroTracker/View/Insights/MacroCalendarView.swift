//
//  MacroCalendarView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/8/26.
//
//  A month-grid calendar where each day shows three small dots
//  (Fat, Carbs, Protein) colored by goal status: green = in range,
//  yellow = under, red = over, gray = no data.
//

import SwiftUI

struct MacroCalendarView: View {
  let month: Date
  let dailyTotals: [Date: DailyMacroTotal]

  /// Called when the user taps a day cell to navigate to that date.
  var onSelectDate: (Date) -> Void

  // Goal ranges (passed in from InsightsView)
  let pMin: Double, pMax: Double
  let cMin: Double, cMax: Double
  let fMin: Double, fMax: Double

  private let calendar = Calendar.current
  private let weekdaySymbols = Calendar.current.veryShortWeekdaySymbols
  private let columns = Array(
    repeating: GridItem(.flexible(), spacing: 4),
    count: 7
  )

  var body: some View {
    VStack(spacing: 8) {
      // Weekday headers
      LazyVGrid(columns: columns, spacing: 4) {
        ForEach(weekdaySymbols, id: \.self) { symbol in
          Text(symbol)
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity)
        }
      }

      // Day cells
      LazyVGrid(columns: columns, spacing: 6) {
        ForEach(dayCells, id: \.id) { cell in
          if cell.isPlaceholder {
            Color.clear.frame(height: 44)
          } else {
            // MARK: - Tap Interaction
            Button(action: {
              onSelectDate(cell.date)
            }) {
              dayCellView(for: cell)
            }
            .buttonStyle(.plain)  // Keeps the custom look
          }
        }
      }
    }
  }

  // MARK: - Day Cell View

  /// Renders a single day: day number + three colored dots for Fat/Carbs/Protein.
  private func dayCellView(for cell: DayCell) -> some View {
    let dayKey = calendar.startOfDay(for: cell.date)
    let totals = dailyTotals[dayKey]
    let isToday = calendar.isDateInToday(cell.date)
    let isFuture = cell.date > Date()

    return VStack(spacing: 3) {
      Text("\(calendar.component(.day, from: cell.date))")
        .font(.system(size: 14, weight: isToday ? .bold : .regular))
        .foregroundColor(
          isToday
            ? .blue
            : (isFuture ? .secondary.opacity(0.4) : .primary)
        )
        // Add a small background circle for touch target
        .frame(width: 28, height: 28)
        .background(isToday ? Color.blue.opacity(0.1) : Color.clear)
        .clipShape(Circle())

      if let totals = totals {
        // Three dots: Fat, Carbs, Protein
        HStack(spacing: 3) {
          dotView(value: totals.fat, min: fMin, max: fMax)
          dotView(value: totals.carbs, min: cMin, max: cMax)
          dotView(value: totals.protein, min: pMin, max: pMax)
        }
      } else {
        // No data — show neutral gray dots (or nothing for future dates)
        HStack(spacing: 3) {
          if !isFuture {
            dotView(color: .gray.opacity(0.3))
            dotView(color: .gray.opacity(0.3))
            dotView(color: .gray.opacity(0.3))
          } else {
            // Empty space to keep grid alignment
            Color.clear.frame(width: 6, height: 6)
          }
        }
      }
    }
    .frame(height: 44)
    .contentShape(Rectangle())  // Ensures the whole cell is tappable
  }

  // MARK: - Dot Views

  /// Returns a colored dot based on whether the value is under/in/over the goal range.
  private func dotView(value: Double, min: Double, max: Double) -> some View {
    let color: Color = {
      if value < min { return Theme.under }
      if value > max { return Theme.over }
      return Theme.good
    }()
    return dotView(color: color)
  }

  /// Renders a small filled circle with the given color.
  private func dotView(color: Color) -> some View {
    Circle().fill(color).frame(width: 6, height: 6)
  }

  /// Represents one cell in the calendar grid — either a real day or a leading placeholder.
  private struct DayCell: Identifiable {
    let id: String
    let date: Date
    let isPlaceholder: Bool
  }

  /// Generates cells for the month grid, including leading placeholder cells
  /// to align the first day with the correct weekday column.
  private var dayCells: [DayCell] {
    guard let monthInterval = calendar.dateInterval(of: .month, for: month),
      let monthRange = calendar.range(of: .day, in: .month, for: month)
    else { return [] }

    var cells: [DayCell] = []

    // Leading empty cells for weekday offset
    let firstWeekday = calendar.component(
      .weekday,
      from: monthInterval.start
    )
    let leadingSpaces = (firstWeekday - calendar.firstWeekday + 7) % 7
    for i in 0..<leadingSpaces {
      cells.append(
        DayCell(id: "empty-\(i)", date: Date(), isPlaceholder: true)
      )
    }

    // Actual day cells
    for day in monthRange {
      if let date = calendar.date(
        bySetting: .day,
        value: day,
        of: monthInterval.start
      ) {
        cells.append(
          DayCell(id: "day-\(day)", date: date, isPlaceholder: false)
        )
      }
    }
    return cells
  }
}
