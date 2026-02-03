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
    
    // Goals
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
        
        _todaysMeals = FetchRequest(
            sortDescriptors: [],
            predicate: NSPredicate(format: "timestamp >= %@ AND timestamp < %@", startOfDay as NSDate, endOfDay as NSDate),
            animation: .default
        )
    }
    
    // Calculated Totals
    var totalP: Double { todaysMeals.reduce(0) { $0 + $1.totalProtein } }
    var totalC: Double { todaysMeals.reduce(0) { $0 + $1.totalCarbs } }
    var totalF: Double { todaysMeals.reduce(0) { $0 + $1.totalFat } }
    var totalKcal: Double { todaysMeals.reduce(0) { $0 + $1.totalCalories } }
    
    var body: some View {
        VStack(spacing: 30) {
            
            // Total Calories Summary
            VStack {
                Text("Total Calories")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Text("\(Int(totalKcal))")
                    .font(.system(size: 48, weight: .heavy, design: .rounded))
            }
            .padding(.bottom, 10)
            
            // The Three Rings
            HStack(spacing: 20) {
                ProgressRing(
                    label: "Protein",
                    value: totalP,
                    min: pMin,
                    max: pMax
                )
                
                ProgressRing(
                    label: "Carbs",
                    value: totalC,
                    min: cMin,
                    max: cMax
                )
                
                ProgressRing(
                    label: "Fat",
                    value: totalF,
                    min: fMin,
                    max: fMax
                )
            }
            .padding(.horizontal)
            
            // Legend / Explanation (Optional)
            HStack(spacing: 15) {
                Label("Under", systemImage: "circle.fill").foregroundColor(.yellow)
                Label("Good", systemImage: "checkmark.circle.fill").foregroundColor(.green)
                Label("Over", systemImage: "xmark.octagon.fill").foregroundColor(.red)
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(.top, 30)
            
            Spacer()
        }
    }
}

// MARK: - The Custom Ring Component
struct ProgressRing: View {
    let label: String
    let value: Double
    let min: Double
    let max: Double
    
    // Safety check to avoid divide-by-zero
    var safeMax: Double {
        return max > 0 ? max : 100
    }
    
    // Calculate fractions (0.0 to 1.0)
    var minFraction: Double {
        return min / safeMax
    }
    
    var currentFraction: Double {
        return value / safeMax
    }
    
    // Determine State for Colors/Icons
    var state: RingState {
        if value < min { return .under }
        if value > max { return .over }
        return .good
    }
    
    var body: some View {
        VStack {
            ZStack {
                // 1. Base Track (Faint Gray)
                Circle()
                    .stroke(lineWidth: 12)
                    .opacity(0.1)
                    .foregroundColor(.primary)
                
                // 2. The "Target Zone" (Shaded Range)
                // This draws an arc from Min to Max to show the user where to aim.
                Circle()
                    .trim(from: CGFloat(minFraction), to: 1.0)
                    .stroke(style: StrokeStyle(lineWidth: 12, lineCap: .butt))
                    .rotationEffect(Angle(degrees: 270.0))
                    .opacity(0.15) // Subtle shading
                    .foregroundColor(.green)
                
                // 3. Current Progress Bar
                // Caps at 1.0 (Full Circle) even if over max
                Circle()
                    .trim(from: 0.0, to: CGFloat(Swift.min(currentFraction, 1.0)))
                    .stroke(style: StrokeStyle(lineWidth: 12, lineCap: .round, lineJoin: .round))
                    .foregroundColor(state.color)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.spring(), value: value)
                
                // 4. Center Content (Icon & Value)
                VStack(spacing: 0) {
                    if state == .over {
                        Image(systemName: "xmark.octagon.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                            .transition(.scale.combined(with: .opacity))
                    } else if state == .good {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        // Show percentage if still under
                        Text("\(Int(currentFraction * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .transition(.opacity)
                    }
                    
                    Text("\(Int(value))g")
                        .font(.headline)
                        .bold()
                }
            }
            .frame(height: 110) // Slightly larger to accommodate the details
            
            Text(label)
                .font(.caption)
                .bold()
                .padding(.top, 5)
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
