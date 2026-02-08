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
    
    // MARK: - State
    @State private var dayOffset: Int = 0
    @State private var displayedOffset: Int = 0
    @State private var showAddMeal = false
    @State private var showSettings = false

    private let anchorDate: Date = Calendar.current.startOfDay(for: Date())

    private var selectedDate: Date {
        Calendar.current.date(byAdding: .day, value: dayOffset, to: anchorDate) ?? anchorDate
    }

    private var displayedDate: Date {
        Calendar.current.date(byAdding: .day, value: displayedOffset, to: anchorDate) ?? anchorDate
    }

    var body: some View {
        VStack(spacing: 0) {
            
            // MARK: - Date Navigator Header
            HStack {
                Button(action: { changeDay(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .padding()
                        .contentShape(Rectangle())
                }
                
                Spacer()
                
                // CENTER DATE DISPLAY
                Button(action: { withAnimation { dayOffset = 0 } }) {
                    VStack(spacing: 2) {
                        Text(displayedDate, style: .date)
                            .font(.headline)
                            .foregroundColor(.primary)
                            .frame(width: 200)
                            .lineLimit(1)

                        Text("Today")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                            .opacity(displayedOffset == 0 ? 1 : 0)
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: { changeDay(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .padding()
                        .contentShape(Rectangle())
                }
            }
            .padding(.vertical, 8)
            // 3. FIXED HEIGHT: Forces the header to stay exactly this tall
            // This prevents the TabView below it from ever being "nudged"
            .frame(height: 60)
            .background(Color(.secondarySystemBackground))
            
            // MARK: - Paging Content Area
            TabView(selection: $dayOffset) {
                // TODO: NOTE: this only allows you to scroll back 10 days. If you set this number too large then perform suffers (there is a huge delay in the middle of swiping).
                ForEach(-10...0, id: \.self) { offset in
                    let dateForPage = Calendar.current.date(
                        byAdding: .day,
                        value: offset,
                        to: anchorDate
                    ) ?? anchorDate
                    
                    LazyView(DailyDashboard(date: dateForPage))
                        .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .onChange(of: dayOffset) { newValue in
            displayedOffset = newValue
        }
        .navigationTitle("Tracker")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gear")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button(action: { showAddMeal.toggle() }) {
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
    
    private func changeDay(by value: Int) {
        withAnimation {
            dayOffset += value
        }
    }
}

struct LazyView<Content: View>: View {
    let build: () -> Content
    init(_ build: @autoclosure @escaping () -> Content) {
        self.build = build
    }
    var body: some View {
        build()
    }
}
