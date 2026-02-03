import SwiftUI
import CoreData

struct StatsView: View {
    @State private var selectedDate = Date()
    
    var body: some View {
        VStack {
            // Date Navigator
            HStack {
                Button(action: { moveDate(by: -1) }) {
                    Image(systemName: "chevron.left")
                        .padding()
                }
                
                Spacer()
                
                VStack {
                    Text(selectedDate, style: .date)
                        .font(.headline)
                        .id(selectedDate)
                    if Calendar.current.isDateInToday(selectedDate) {
                        Text("Today").font(.caption).foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                Button(action: { moveDate(by: 1) }) {
                    Image(systemName: "chevron.right")
                        .padding()
                }
                .disabled(Calendar.current.isDateInToday(selectedDate))
            }
            .padding(.bottom)
#if os(iOS)
            .background(
                Color(uiColor: .secondarySystemBackground)
            )
#else
            .background(
                Color(nsColor: .controlBackgroundColor)
            )
#endif
            
            // The Content
            ScrollView {
                DailyRingContent(date: selectedDate)
                    .padding(.top, 20)
            }
            // Swipe Gestures
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

// MARK: - Ring Content Subview
struct DailyRingContent: View {
    @FetchRequest var todaysMeals: FetchedResults<MealEntity>
    
    // Add State for HealthKit Data
    @State private var caloriesBurned: Double = 0.0
    
    // Pass the date in so we can detect changes
    let date: Date
    
    // Goals
    @AppStorage("goal_p_min") var pMin: Double = 150
    @AppStorage("goal_p_max") var pMax: Double = 180
    @AppStorage("goal_c_min") var cMin: Double = 200
    @AppStorage("goal_c_max") var cMax: Double = 300
    @AppStorage("goal_f_min") var fMin: Double = 60
    @AppStorage("goal_f_max") var fMax: Double = 80
    
    init(date: Date) {
        self.date = date
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        _todaysMeals = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(format: "timestamp >= %@ AND timestamp < %@", startOfDay as NSDate, endOfDay as NSDate),
            animation: .default
        )
    }
    
    var totalP: Double { todaysMeals.reduce(0) { $0 + $1.totalProtein } }
    var totalC: Double { todaysMeals.reduce(0) { $0 + $1.totalCarbs } }
    var totalF: Double { todaysMeals.reduce(0) { $0 + $1.totalFat } }
    var totalKcal: Double { todaysMeals.reduce(0) { $0 + $1.totalCalories } }
    
    var body: some View {
        VStack(spacing: 30) {
            
            // MARK: - NEW CALORIE COMPARISON
            HStack(spacing: 40) {
                // In (Food)
                VStack {
                    Text("Eaten")
                        .font(.caption).bold().foregroundColor(.secondary)
                    Text("\(Int(totalKcal))")
                        .font(.title2).bold()
                }
                
                Text("-")
                    .foregroundColor(.secondary)
                
                // Out (HealthKit)
                VStack {
                    Text("Burned")
                        .font(.caption).bold().foregroundColor(.secondary)
                    Text("\(Int(caloriesBurned))")
                        .font(.title2).bold()
                        .foregroundColor(.orange)
                }
                
                Text("=")
                    .foregroundColor(.secondary)
                
                // Net
                VStack {
                    Text("Net")
                        .font(.caption).bold().foregroundColor(.secondary)
                    Text("\(Int(totalKcal - caloriesBurned))")
                        .font(.title2).bold()
                        // Color logic: If Net is negative, you are in deficit (Green usually?)
                        .foregroundColor(totalKcal - caloriesBurned < 0 ? .green : .primary)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            
            // The Three Rings (Unchanged)
            HStack(spacing: 20) {
                ProgressRing(label: "Protein", value: totalP, min: pMin, max: pMax)
                ProgressRing(label: "Carbs", value: totalC, min: cMin, max: cMax)
                ProgressRing(label: "Fat", value: totalF, min: fMin, max: fMax)
            }
            .padding(.horizontal)
            
            Spacer()
        }
        // MARK: - FETCH TRIGGER
        .task(id: date) {
            // Trigger the fetch whenever the date changes
            caloriesBurned = await HealthManager.shared.fetchCaloriesBurned(for: date)
        }
        .onAppear {
            // Ask for permission the first time the view loads
            HealthManager.shared.requestAuthorization()
        }
    }
}

// MARK: - The Custom Ring Component
struct ProgressRing: View {
    let label: String
    let value: Double
    let min: Double
    let max: Double
    
    // 1. Math Helpers
    private func sanitize(_ val: Double) -> Double {
        if val.isNaN || val.isInfinite { return 0.0 }
        return val
    }
    
    var safeMax: Double {
        let m = sanitize(max)
        return m > 0 ? m : 100
    }
    
    // The "Goal Zone" arc (Min to Max)
    var minFraction: CGFloat {
        let val = sanitize(min) / safeMax
        return CGFloat(sanitize(val))
    }
    
    // Standard Progress (0.0 to 1.0)
    var currentFraction: CGFloat {
        let val = sanitize(value) / safeMax
        return CGFloat(sanitize(val))
    }
    
    // Overflow Logic (How much past 100% are we?)
    // Uses modulo to handle lapping multiple times if needed
    var overflowFraction: CGFloat {
        let fraction = currentFraction
        if fraction > 1.0 {
            return fraction.truncatingRemainder(dividingBy: 1.0)
        }
        return 0.0
    }
    
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
                        .foregroundColor(Color(red: 0.6, green: 0, blue: 0)) // Dark Blood Red
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

enum RingState {
    case under, good, over
    
    var color: Color {
        switch self {
        case .under: return .yellow
        case .good: return .green
        case .over: return .red
        }
    }
    
    var icon: String? {
        switch self {
        case .under: return nil // Or use "arrow.up" to indicate "eat more"
        case .good: return "checkmark"
        case .over: return "xmark.octagon.fill"
        }
    }
}
