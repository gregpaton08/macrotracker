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
    
    // 1. Helper to kill NaNs/Infinity
    private func sanitize(_ val: Double) -> Double {
        if val.isNaN || val.isInfinite { return 0.0 }
        return val
    }
    
    // 2. Safe Max (Prevents divide by zero)
    var safeMax: Double {
        let m = sanitize(max)
        return m > 0 ? m : 100 // Default to 100 if 0 to avoid crash
    }
    
    // 3. Safe Fractions for CoreGraphics
    var minFraction: CGFloat {
        let val = sanitize(min) / safeMax
        return CGFloat(sanitize(val))
    }
    
    var currentFraction: CGFloat {
        let val = sanitize(value) / safeMax
        // Clamp to 1.0 for the progress bar (so it doesn't wrap wildly)
        return CGFloat(sanitize(val > 1.0 ? 1.0 : val))
    }
    
    var state: RingState {
        // Safe comparisons
        let val = sanitize(value)
        let minVal = sanitize(min)
        let maxVal = sanitize(max)
        
        if val < minVal { return .under }
        if val > maxVal { return .over }
        return .good
    }
    
    var body: some View {
        VStack {
            ZStack {
                // Base Track
                Circle()
                    .stroke(lineWidth: 8)
                    .opacity(0.1)
                    .foregroundColor(.primary)
                
                // Target Zone (Safe Trim)
                Circle()
                    .trim(from: minFraction, to: 1.0)
                    .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .butt))
                    .rotationEffect(Angle(degrees: 270.0))
                    .opacity(0.15)
                    .foregroundColor(.green)
                
                // Progress Bar (Safe Trim)
                Circle()
                    .trim(from: 0.0, to: currentFraction)
                    .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                    .foregroundColor(state.color)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.spring(), value: value)
                
                // Center Content
                VStack(spacing: 2) {
                    Text("\(Int(sanitize(value)))g")
                        .font(.headline)
                        .bold()
                        .minimumScaleFactor(0.6)
                    
                    if state == .over {
                        Image(systemName: "xmark.octagon.fill")
                            .foregroundColor(.red)
                            .font(.subheadline)
                    } else if state == .good {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.subheadline)
                    } else {
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
