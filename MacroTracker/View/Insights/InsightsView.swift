//
//  InsightsView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/8/26.
//
//  Main Insights screen: calendar with macro-status dots + averages card.
//

import SwiftUI
import CoreData

struct InsightsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    // MARK: - Calendar State

    @State private var displayedMonth = Date()
    @State private var dailyTotals: [Date: DailyMacroTotal] = [:]

    /// Tapping a calendar day navigates to that date's TrackerView.
    @State private var selectedDateToNavigate: Date?
    @State private var isNavigating = false

    // MARK: - Averages State

    @State private var selectedRange: DateRangeOption = .week
    @State private var customStart = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEnd = Date()
    @State private var averages = MacroAverage(protein: 0, carbs: 0, fat: 0, dayCount: 0)

    // MARK: - Goal Ranges (shared with DailyDashboard / SettingsView)

    @AppStorage("goal_p_min") private var pMin: Double = 150
    @AppStorage("goal_p_max") private var pMax: Double = 180
    @AppStorage("goal_c_min") private var cMin: Double = 200
    @AppStorage("goal_c_max") private var cMax: Double = 300
    @AppStorage("goal_f_min") private var fMin: Double = 60
    @AppStorage("goal_f_max") private var fMax: Double = 80

    /// Time period options for the daily averages section.
    enum DateRangeOption: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        case custom = "Custom"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                calendarSection
                Divider().padding(.horizontal)
                averagesSection
            }
            .padding(.vertical)
        }
        .navigationTitle("Insights")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        
        // MARK: - Navigation Trigger
        // This hidden link activates when isNavigating becomes true
        .navigationDestination(isPresented: $isNavigating) {
            if let date = selectedDateToNavigate {
                // Initialize TrackerView with the clicked date, and isRoot=false
                TrackerView(initialDate: date, isRoot: false)
            }
        }
        
        // Refresh Logic
        .onAppear { refreshAll() }
        .onChange(of: displayedMonth) { refreshCalendar() }
        .onChange(of: selectedRange) { refreshAverages() }
        .onChange(of: customStart) { if selectedRange == .custom { refreshAverages() } }
        .onChange(of: customEnd) { if selectedRange == .custom { refreshAverages() } }
    }

    // MARK: - Calendar Section
    private var calendarSection: some View {
        VStack(spacing: 12) {
            HStack {
                Button { changeMonth(by: -1) } label: { Image(systemName: "chevron.left").padding(.horizontal, 8) }
                Spacer()
                Text(monthYearString(for: displayedMonth)).font(.headline)
                Spacer()
                Button { changeMonth(by: 1) } label: { Image(systemName: "chevron.right").padding(.horizontal, 8) }
            }
            .padding(.horizontal)

            MacroCalendarView(
                month: displayedMonth,
                dailyTotals: dailyTotals,
                onSelectDate: { date in
                    // Trigger Navigation
                    self.selectedDateToNavigate = date
                    self.isNavigating = true
                },
                pMin: pMin, pMax: pMax,
                cMin: cMin, cMax: cMax,
                fMin: fMin, fMax: fMax
            )
            .padding(.horizontal, 8)
        }
    }

    // MARK: - Averages Section

    private var averagesSection: some View {
        VStack(spacing: 16) {
            Text("Daily Averages").font(.headline)
            Picker("Range", selection: $selectedRange) {
                ForEach(DateRangeOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            if selectedRange == .custom {
                HStack {
                    DatePicker("From", selection: $customStart, displayedComponents: .date)
                    DatePicker("To", selection: $customEnd, displayedComponents: .date)
                }
                .labelsHidden()
                .padding(.horizontal)
            }

            if averages.dayCount == 0 {
                Text("No meals logged in this period.")
                    .foregroundColor(.secondary)
                    .font(.subheadline)
                    .padding()
            } else {
                AveragesMacroView(
                    averages: averages,
                    pMin: pMin, pMax: pMax,
                    cMin: cMin, cMax: cMax,
                    fMin: fMin, fMax: fMax
                )
                .padding(.horizontal)
                
                Text("Based on \(averages.dayCount) day\(averages.dayCount == 1 ? "" : "s") with logged meals")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Data Refresh

    private func refreshAll() {
        refreshCalendar()
        refreshAverages()
    }
    
    private func refreshCalendar() {
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth) else { return }
        dailyTotals = MacroStatsService.dailyTotals(from: monthInterval.start, to: monthInterval.end, context: viewContext)
    }
    
    private func refreshAverages() {
        let (start, end) = dateRange(for: selectedRange)
        averages = MacroStatsService.averages(from: start, to: end, context: viewContext)
    }
    
    /// Computes the `[start, end)` interval for the selected date range option.
    private func dateRange(for option: DateRangeOption) -> (Date, Date) {
        let calendar = Calendar.current
        let endOfToday = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))!
        switch option {
        case .week:
            let start = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: Date()))!
            return (start, endOfToday)
        case .month:
            let start = calendar.date(byAdding: .month, value: -1, to: calendar.startOfDay(for: Date()))!
            return (start, endOfToday)
        case .custom:
            let start = calendar.startOfDay(for: customStart)
            let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: customEnd))!
            return (start, end)
        }
    }
    
    // MARK: - Helpers

    /// Advances or reverses the displayed calendar month.
    private func changeMonth(by value: Int) {
        withAnimation {
            displayedMonth = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) ?? displayedMonth
        }
    }
    
    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
}
