import SwiftUI
import Charts
import CoreData

struct StatsView: View {
    @State private var selectedDate = Date()
    
    var body: some View {
        
            VStack {
                // Date Navigator
                HStack {
                    Button(action: { moveDate(by: -1) }) {
                        Image(systemName: "chevron.left")
                    }
                    
                    Spacer()
                    
                    Text(selectedDate, style: .date)
                        .font(.headline)
                        .id(selectedDate) // Fade animation trigger
                        .transition(.opacity)
                    
                    Spacer()
                    
                    Button(action: { moveDate(by: 1) }) {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(Calendar.current.isDateInToday(selectedDate)) // Optional: Disable future
                }
                .padding()
                
                // The Content (Swipable)
                DailyChartContent(date: selectedDate)
                    .background(Color.white.opacity(0.01)) // Hack to make empty space swipeable
                    .gesture(
                        DragGesture()
                            .onEnded { value in
                                if value.translation.width < -50 {
                                    // Swipe Left (Next Day)
                                    if !Calendar.current.isDateInToday(selectedDate) {
                                        moveDate(by: 1)
                                    }
                                } else if value.translation.width > 50 {
                                    // Swipe Right (Previous Day)
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
    @FetchRequest var todaysFoods: FetchedResults<FoodEntity>
    
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
        
        _todaysFoods = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(format: "timestamp >= %@ AND timestamp < %@", startOfDay as NSDate, endOfDay as NSDate),
            animation: .default
        )
    }
    
    // Actual Data
    var totals: [MacroData] {
        let p = todaysFoods.reduce(0) { $0 + $1.protein }
        let c = todaysFoods.reduce(0) { $0 + $1.carbs }
        let f = todaysFoods.reduce(0) { $0 + $1.fat }
        
        return [
            MacroData(type: "Protein", grams: p, color: .blue),
            MacroData(type: "Carbs", grams: c, color: .green),
            MacroData(type: "Fat", grams: f, color: .red)
        ]
    }
    
    // Target Zones Data
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
                    Text("\(Int(todaysFoods.reduce(0){ $0 + $1.calories }))")
                        .font(.title).bold()
                }
                Divider().frame(height: 40)
                VStack {
                    Text("Entries").font(.caption).foregroundColor(.secondary)
                    Text("\(todaysFoods.count)")
                        .font(.title).bold()
                }
            }
            .padding(.bottom, 20)
            
            // Chart
            Chart {
                // 1. Draw Target Zones (Background Layer)
                ForEach(targets) { target in
                    RectangleMark(
                        x: .value("Macro", target.type),
                        yStart: .value("Min", target.min),
                        yEnd: .value("Max", target.max)
                    )
                    .foregroundStyle(.gray.opacity(0.15)) // Subtle background box
                    .annotation(position: .overlay, alignment: .bottom) {
                        Text("Goal")
                            .font(.caption2)
                            .foregroundColor(.gray.opacity(0.8))
                    }
                }
                
                // 2. Draw Actual Bars (Foreground Layer)
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
            
            Spacer()
        }
        .padding()
    }
}

// Data Model for Chart
struct MacroData: Identifiable {
    let id = UUID()
    let type: String
    let grams: Double
    let color: Color
}

// New Helper Struct for Targets
struct MacroTarget: Identifiable {
    let id = UUID()
    let type: String
    let min: Double
    let max: Double
}
