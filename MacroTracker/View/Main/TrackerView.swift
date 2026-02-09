//
//  TrackerView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/28/26.
//

import SwiftUI
import CoreData

struct TrackerView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @State private var selectedDate = Date()
    @State private var showAddMeal = false
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            dateNavigator
            DailyDashboard(date: selectedDate)
        }
        .navigationTitle("Tracker")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarLeading) {
                HStack(spacing: 12) {
                    Button { showSettings.toggle() } label: {
                        Image(systemName: "gear")
                    }
                    // New: Insights button — pushes to the Insights screen
                    NavigationLink(destination: InsightsView()) {
                        Image(systemName: "chart.bar")
                    }
                }
            }
            #else
            ToolbarItem(placement: .automatic) {
                NavigationLink(destination: InsightsView()) {
                    Image(systemName: "chart.bar")
                }
            }
            #endif

            ToolbarItem(placement: .primaryAction) {
                Button { showAddMeal.toggle() } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddMeal) {
            AddMealView(
                viewModel: MacroViewModel(context: viewContext),
                targetDate: selectedDate
            )
        }
        .sheet(isPresented: $showSettings) {
            NavigationView {
                SettingsView()
            }
        }
    }

    private var dateNavigator: some View {
        HStack {
            Button { moveDate(by: -1) } label: {
                Image(systemName: "chevron.left").padding()
            }

            Spacer()

            Button { withAnimation { selectedDate = Date() } } label: {
                VStack {
                    Text(selectedDate, style: .date)
                        .font(.headline)
                        .foregroundColor(.primary)
                    if Calendar.current.isDateInToday(selectedDate) {
                        Text("Today").font(.caption).foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            Button { moveDate(by: 1) } label: {
                Image(systemName: "chevron.right").padding()
            }
        }
        .padding(.vertical, 10)
        #if os(iOS)
        .background(Color(uiColor: .secondarySystemBackground))
        #else
        .background(Color(nsColor: .controlBackgroundColor))
        #endif
    }

    private func moveDate(by days: Int) {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) ?? Date()
        }
    }
}
