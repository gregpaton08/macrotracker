//
//  TrackerView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/28/26.
//
//  Horizontally-paged daily tracker. Each page is a DailyDashboard for
//  one calendar day. A floating date header with chevrons and a calendar
//  picker allows quick date navigation. The toolbar provides access to
//  the Add Meal sheet.
//

import CoreData
import SwiftUI

/// Defers view body evaluation until the view is actually rendered,
/// preventing all 20+ dashboard pages from computing at once.
private struct LazyView<Content: View>: View {
  let build: () -> Content
  init(_ build: @autoclosure @escaping () -> Content) { self.build = build }
  var body: Content { build() }
}

struct TrackerView: View {
  @Environment(\.managedObjectContext) private var viewContext

  // MARK: - Configuration

  /// Index that maps to "today" in the paging TabView.
  private let centerIndex = 5000
  /// When `false`, toolbar navigation items (gear, chart) are hidden
  /// so this view can be pushed from InsightsView without duplicate controls.
  private let isRoot: Bool

  /// Page range for the TabView, centered on the initial date.
  private let pageRangeStart: Int
  private let pageRangeEnd: Int

  // MARK: - State

  @State private var selectedIndex: Int
  @State private var selectedDate: Date

  @State private var showCalendar = false
  @State private var showAddMeal = false

  // MARK: - Initializer

  /// - Parameters:
  ///   - initialDate: The calendar day to show on first appearance (defaults to today).
  ///   - isRoot: Pass `false` when pushing from InsightsView to hide redundant toolbar items.
  init(initialDate: Date = Date(), isRoot: Bool = true) {
    self.isRoot = isRoot

    // 1. Calculate the offset from Today
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    let target = calendar.startOfDay(for: initialDate)
    let diff = calendar.dateComponents([.day], from: today, to: target).day ?? 0

    // 2. Set initial state
    let initialIndex = 5000 + diff
    _selectedDate = State(initialValue: target)
    _selectedIndex = State(initialValue: initialIndex)

    // 3. Center page range on the initial date
    pageRangeStart = initialIndex - 20
    pageRangeEnd = initialIndex + 2
  }

  var body: some View {
    ZStack(alignment: .top) {

      // MARK: - Layer 1: Paging Dashboard
      TabView(selection: $selectedIndex) {
        // TODO: NOTE: this might cause serious lag when swiping since the range is huge.
        ForEach(pageRangeStart...pageRangeEnd, id: \.self) { index in
          LazyView(DailyDashboard(date: dateFromIndex(index)))
            .tag(index)
            .padding(.top, 60)  // Push content below floating header
        }
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .edgesIgnoringSafeArea(.bottom)
      .background(Theme.background)

      // MARK: - Layer 2: Floating Date Header
      VStack(spacing: 0) {
        HStack {
          // Prev Day
          Button(action: { withAnimation { selectedIndex -= 1 } }) {
            Image(systemName: "chevron.left")
              .font(.system(size: 16, weight: .semibold))
              .frame(width: 44, height: 44)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)

          Spacer()

          // Calendar Picker
          Button(action: { showCalendar = true }) {
            HStack(spacing: 6) {
              Image(systemName: "calendar")
              Text(selectedDate, style: .date).font(.headline)

              if Calendar.current.isDateInToday(selectedDate) {
                Text("Today")
                  .font(.caption).bold()
                  .padding(.horizontal, 6).padding(.vertical, 2)
                  .background(Theme.tint.opacity(0.1))
                  .foregroundColor(Theme.tint)
                  .cornerRadius(4)
              }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(.regularMaterial)
            .cornerRadius(20)
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
          }
          .buttonStyle(.plain)

          Spacer()

          // Next Day
          Button(action: { withAnimation { selectedIndex += 1 } }) {
            Image(systemName: "chevron.right")
              .font(.system(size: 16, weight: .semibold))
              .frame(width: 44, height: 44)
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)

        Divider()
      }
    }
    .navigationTitle(isRoot ? "Tracker" : "Detail")  // Change title if drilled down
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
    #endif

    // MARK: - Toolbar Logic
    .toolbar {
      // RIGHT: Actions (Today + Add) — only when used as root tab
      if isRoot {
        ToolbarItem(placement: .primaryAction) {
          HStack(spacing: 16) {
            if !Calendar.current.isDateInToday(selectedDate) {
              Button("Today") {
                withAnimation { selectedIndex = centerIndex }
              }
              .font(.caption).bold()
              .buttonStyle(.bordered)
            }

            Button(action: { showAddMeal.toggle() }) {
              Image(systemName: "plus.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(Theme.tint)
            }
          }
        }
      }
    }

    // MARK: - Sheets & Logic
    .sheet(isPresented: $showAddMeal) {
      AddMealView(viewModel: MacroViewModel(context: viewContext), targetDate: selectedDate)
    }
    .sheet(isPresented: $showCalendar) {
      VStack {
        DatePicker("Select Date", selection: $selectedDate, displayedComponents: [.date])
          .datePickerStyle(.graphical)
          .padding()
          .onChange(of: selectedDate) { _ in showCalendar = false }
      }
      .presentationDetents([.medium])
    }

    // Logic Sync
    .onChange(of: selectedIndex) { newIndex in
      selectedDate = dateFromIndex(newIndex)
    }
    .onChange(of: selectedDate) { newDate in
      let newIndex = indexFromDate(newDate)
      if newIndex != selectedIndex { selectedIndex = newIndex }
    }
  }

  // MARK: - Index ↔ Date Helpers

  /// Converts a TabView page index to a calendar date relative to today.
  private func dateFromIndex(_ index: Int) -> Date {
    let diff = index - centerIndex
    let today = Calendar.current.startOfDay(for: Date())
    return Calendar.current.date(byAdding: .day, value: diff, to: today) ?? today
  }

  /// Converts a calendar date to the corresponding TabView page index.
  private func indexFromDate(_ date: Date) -> Int {
    let today = Calendar.current.startOfDay(for: Date())
    let target = Calendar.current.startOfDay(for: date)
    let diff = Calendar.current.dateComponents([.day], from: today, to: target).day ?? 0
    return centerIndex + diff
  }
}
