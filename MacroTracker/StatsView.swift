import SwiftUI
import Charts
import CoreData

import SwiftUI
import Charts
import CoreData

struct StatsView: View {
    @State private var selectedDate = Date()
    
    var body: some View {
        // NOTE: We removed NavigationView here because ContentView handles it now
        VStack {
            // Date Navigator
            HStack {
                Button(action: { moveDate(by: -1) }) {
                    Image(systemName: "chevron.left")
                }
                
                Spacer()
                
                Text(selectedDate, style: .date)
                    .font(.headline)
                    .id(selectedDate)
                    .transition(.opacity)
                
                Spacer()
                
                Button(action: { moveDate(by: 1) }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(Calendar.current.isDateInToday(selectedDate))
            }
            .padding()
            
            // The Content
            DailyChartContent(date: selectedDate)
                .background(Color.white.opacity(0.01))
                .gesture(
                    DragGesture()
                        .onEnded { value in
                            if value.translation.width < -50 {
                                if !Calendar.current.isDateInToday(selectedDate) {
                                    moveDate(by: 1)
                                }
                            } else if value.translation.width > 50 {
                                moveDate(by: -1)
                            }
                        }
                )
        }
        .navigationTitle("Stats")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
    
    private func moveDate(by days: Int) {
        withAnimation {
            selectedDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) ?? Date()
        }
    }
}

// MARK: - Subview with Dynamic FetchRequest
struct DailyChartContent: View {
    // FIX: Fetch MealEntity (the Parent), not FoodEntity (the Ingredients)
    @FetchRequest var todaysMeals: FetchedResults<MealEntity>
    
    // Read Goals from Storage
    @AppStorage("goal_p_min") var pMin: Double = 150
    @AppStorage("goal_p_max") var pMax: Double = 180
    @AppStorage("goal_c_min") var cMin: Double = 200
    @AppStorage("goal_c_max") var cMax: Double = 300
    @AppStorage("goal_f_min") var fMin: Double = 60
    @AppStorage("goal_f_max") var fMax: Double = 80
    
    init(date: Date) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // FIX: Predicate targets MealEntity
        _todaysMeals = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(format: "timestamp >= %@ AND timestamp < %@", startOfDay as NSDate, endOfDay as NSDate),
            animation: .default
        )
    }
    
    // FIX: Calculate totals using MealEntity properties (totalProtein, etc.)
    var totals: [MacroData] {
        let p = todaysMeals.reduce(0) { $0 + $1.totalProtein }
        let c = todaysMeals.reduce(0) { $0 + $1.totalCarbs }
        let f = todaysMeals.reduce(0) { $0 + $1.totalFat }
        
        return [
            MacroData(type: "Protein", grams: p, color: .blue),
            MacroData(type: "Carbs", grams: c, color: .green),
            MacroData(type: "Fat", grams: f, color: .red)
        ]
    }
    
    var targets: [MacroTarget] {
        [
            MacroTarget(type: "Protein", min: pMin, max: pMax),
            MacroTarget(type: "Carbs", min: cMin, max: cMax),
            MacroTarget(type: "Fat", min: fMin, max: fMax)
        ]
    }
    
    var body: some View {
        VStack {
            // Stats Summary
            HStack(spacing: 20) {
                VStack {
                    Text("Calories").font(.caption).foregroundColor(.secondary)
                    // FIX: Sum totalCalories from Meals
                    Text("\(Int(todaysMeals.reduce(0){ $0 + $1.totalCalories }))")
                        .font(.title).bold()
                }
                Divider().frame(height: 40)
                VStack {
                    Text("Entries").font(.caption).foregroundColor(.secondary)
                    Text("\(todaysMeals.count)")
                        .font(.title).bold()
                }
            }
            .padding(.bottom, 20)
            
            // Chart
            if todaysMeals.isEmpty {
                Spacer()
                Text("No data for this day").foregroundColor(.gray)
                Spacer()
            } else {
                Chart {
                    // Background Goals
                    ForEach(targets) { target in
                        RectangleMark(
                            x: .value("Macro", target.type),
                            yStart: .value("Min", target.min),
                            yEnd: .value("Max", target.max)
                        )
                        .foregroundStyle(Color.gray.opacity(0.15))
                    }
                    
                    // Foreground Data
                    ForEach(totals) { item in
                        BarMark(
                            x: .value("Macro", item.type),
                            y: .value("Grams", item.grams)
                        )
                        .foregroundStyle(item.color)
                        .annotation(position: .top) {
                            Text("\(Int(item.grams))g")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(height: 300)
                .padding()
            }
            
            Spacer()
        }
        .padding()
    }
}

struct MacroData: Identifiable {
    let id = UUID()
    let type: String
    let grams: Double
    let color: Color
}

struct MacroTarget: Identifiable {
    let id = UUID()
    let type: String
    let min: Double
    let max: Double
}
