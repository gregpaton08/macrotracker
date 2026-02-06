//
//  TrackerView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/28/26.
//
// This is the main view where you enter in food you ate and it shows a history of food items.

import SwiftUI
import CoreData

struct TrackerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // Date State
    @State private var selectedDate = Date()
    @State private var showAddMeal = false
    @State private var showSettings = false
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Date Navigator
            HStack {
                Button(action: { moveDate(by: -1) }) {
                    Image(systemName: "chevron.left").padding()
                }
                
                Spacer()
                
                Button(action: { withAnimation { selectedDate = Date() } }) {
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
                
                Button(action: { moveDate(by: 1) }) {
                    Image(systemName: "chevron.right").padding()
                }
            }
            .padding(.vertical, 10)
#if os(iOS)
            .background(
                Color(uiColor: .secondarySystemBackground))
#else
            .background(
                Color(nsColor: .controlBackgroundColor))
#endif
            
            // MARK: - Combined Dashboard
            DailyDashboard(date: selectedDate)
        }
        .navigationTitle("Tracker")
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
#if os(iOS)
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gear")
                }
            }
#endif
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddMeal.toggle() }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddMeal) {
            AddMealView(viewModel: MacroViewModel(context: viewContext))
        }
        .sheet(isPresented: $showSettings) {
            NavigationView {
                SettingsView()
            }
        }
    }
    
    private func moveDate(by days: Int) {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) ?? Date()
        }
    }
}
