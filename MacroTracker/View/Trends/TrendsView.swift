//
//  TrendsView.swift
//  MacroTracker
//

import CoreData
import HealthKit
import SwiftUI

// MARK: - Trend Data Models

enum TrendDirection {
    case up, down, flat
    
    var icon: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .flat: return "arrow.right"
        }
    }
}

enum TrendType {
    case good, bad, neutral
    
    var color: Color {
        switch self {
        case .good: return Theme.good
        case .bad: return Theme.over
        case .neutral: return .secondary
        }
    }
}

struct TrendItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let iconColor: Color
    
    let currentAvg: Double
    let previousAvg: Double
    let unit: String
    
    let direction: TrendDirection
    let type: TrendType
    let message: String
}

// MARK: - Main View

struct TrendsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    
    // Read the user's energy settings so the math matches the DailyDashboard
    @AppStorage("energy_source") var energySource: String = "active"
    @AppStorage("combine_workouts_and_steps") var combineSources: Bool = false
    
    @State private var isLoading = true
    @State private var trends: [TrendItem] = []
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if isLoading {
                    ProgressView("Analyzing 14-day history...")
                        .padding(.top, 40)
                } else if trends.isEmpty {
                    Text("Not enough data to calculate trends.")
                        .foregroundColor(.secondary)
                        .padding(.top, 40)
                } else {
                    Text("Comparing your daily average over the last 7 days to the 7 days prior.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    
                    ForEach(trends) { trend in
                        TrendCard(trend: trend)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Trends")
        .task {
            await calculateTrends()
        }
    }
    
    // MARK: - Trend Engine Math
    
    /// Pulls 14 days of data, splits it into two 7-day chunks, and generates the UI cards.
    private func calculateTrends() async {
        isLoading = true
        defer { isLoading = false }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Define our windows:
        // Current: Last 7 days (Days -6 to 0)
        // Previous: Prior 7 days (Days -13 to -7)
        let windowEnd = calendar.date(byAdding: .day, value: 1, to: today)!
        let windowMid = calendar.date(byAdding: .day, value: -6, to: today)!
        let windowStart = calendar.date(byAdding: .day, value: -13, to: today)!
        
        // 1. Fetch Core Data Meals
        let currentMeals = MacroStatsService.dailyTotals(from: windowMid, to: windowEnd, context: viewContext)
        let previousMeals = MacroStatsService.dailyTotals(from: windowStart, to: windowMid, context: viewContext)
        
        // 2. Fetch HealthKit Burned Calories
        var currentBurned = [Double]()
        var previousBurned = [Double]()
        
        for i in 0..<14 {
            let targetDate = calendar.date(byAdding: .day, value: -i, to: today)!
            let active = await HealthManager.shared.fetchCaloriesBurned(for: targetDate)
            
            var totalForDay = active
            
            // Replicate the math logic from DailyDashboard based on user settings
            if energySource == "total" {
                let basal = await HealthManager.shared.fetchBasalEnergyBurned(for: targetDate)
                totalForDay += basal
            } else if combineSources {
                #if os(iOS)
                let workouts = await HealthManager.shared.fetchWorkouts(for: targetDate)
                let workoutKcal = workouts.reduce(0) { $0 + ($1.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0) }
                totalForDay += workoutKcal
                #endif
            }
            
            if i < 7 {
                currentBurned.append(totalForDay)
            } else {
                previousBurned.append(totalForDay)
            }
        }
        
        // 3. Aggregate Averages (/ 7 days)
        let curEaten = currentMeals.values.reduce(0) { $0 + $1.calories } / 7.0
        let prevEaten = previousMeals.values.reduce(0) { $0 + $1.calories } / 7.0
        
        let curBurned = currentBurned.reduce(0, +) / 7.0
        let prevBurned = previousBurned.reduce(0, +) / 7.0
        
        let curNet = curEaten - curBurned
        let prevNet = prevEaten - prevBurned
        
        let curP = currentMeals.values.reduce(0) { $0 + $1.protein } / 7.0
        let prevP = previousMeals.values.reduce(0) { $0 + $1.protein } / 7.0
        
        let curC = currentMeals.values.reduce(0) { $0 + $1.carbs } / 7.0
        let prevC = previousMeals.values.reduce(0) { $0 + $1.carbs } / 7.0
        
        let curF = currentMeals.values.reduce(0) { $0 + $1.fat } / 7.0
        let prevF = previousMeals.values.reduce(0) { $0 + $1.fat } / 7.0
        
        // 4. Build Cards
        var newTrends: [TrendItem] = []
        
        // Active Energy
        newTrends.append(buildCard(
            title: "Active Energy", icon: "flame.fill", iconColor: .orange,
            cur: curBurned, prev: prevBurned, unit: "kcal",
            higherIsBetter: true,
            msgUp: "You're burning more energy a day on average.",
            msgDown: "You're burning less energy a day on average."
        ))
        
        // Net Calories
        newTrends.append(buildCard(
            title: "Net Calories", icon: "bolt.fill", iconColor: .yellow,
            cur: curNet, prev: prevNet, unit: "kcal",
            higherIsBetter: nil, // Neutral
            msgUp: "Your net energy intake is trending higher.",
            msgDown: "Your net energy intake is trending lower."
        ))
        
        // Protein
        newTrends.append(buildCard(
            title: "Protein", icon: "fish.fill", iconColor: Theme.good,
            cur: curP, prev: prevP, unit: "g",
            higherIsBetter: true,
            msgUp: "You're eating more protein a day on average.",
            msgDown: "You're eating less protein a day on average."
        ))
        
        // Carbs
        newTrends.append(buildCard(
            title: "Carbs", icon: "leaf.fill", iconColor: Theme.tint,
            cur: curC, prev: prevC, unit: "g",
            higherIsBetter: nil,
            msgUp: "Your carbohydrate intake is trending up.",
            msgDown: "Your carbohydrate intake is trending down."
        ))
        
        // Fat
        newTrends.append(buildCard(
            title: "Fat", icon: "drop.fill", iconColor: Theme.over,
            cur: curF, prev: prevF, unit: "g",
            higherIsBetter: false,
            msgUp: "Your fat intake is trending up.",
            msgDown: "Your fat intake is trending down."
        ))
        
        await MainActor.run {
            withAnimation {
                self.trends = newTrends
            }
        }
    }
    
    /// Helper to evaluate the math and generate the formatted TrendItem
    private func buildCard(title: String, icon: String, iconColor: Color, cur: Double, prev: Double, unit: String, higherIsBetter: Bool?, msgUp: String, msgDown: String) -> TrendItem {
        
        let diff = cur - prev
        let threshold = 2.0 // Ignore tiny fluctuations
        
        let direction: TrendDirection
        if diff > threshold { direction = .up }
        else if diff < -threshold { direction = .down }
        else { direction = .flat }
        
        let type: TrendType
        if direction == .flat {
            type = .neutral
        } else if let higherIsBetter = higherIsBetter {
            if (direction == .up && higherIsBetter) || (direction == .down && !higherIsBetter) {
                type = .good
            } else {
                type = .bad
            }
        } else {
            type = .neutral // Neutral metrics (like carbs) just get default coloring
        }
        
        let message: String
        if direction == .up { message = msgUp }
        else if direction == .down { message = msgDown }
        else { message = "Your average has remained consistent." }
        
        return TrendItem(title: title, icon: icon, iconColor: iconColor, currentAvg: cur, previousAvg: prev, unit: unit, direction: direction, type: type, message: message)
    }
}

// MARK: - Trend Card UI

struct TrendCard: View {
    let trend: TrendItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: trend.icon)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(trend.iconColor)
                Text(trend.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(trend.iconColor)
            }
            
            // Insight Message
            Text(trend.message)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            
            // Metrics & Arrow
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(trend.currentAvg))")
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                        Text(trend.unit)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                    }
                    Text("Last 7 Days")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
                
                Spacer()
                
                // Big Trend Arrow
                Image(systemName: trend.direction.icon)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(trend.type.color)
                    .padding(.horizontal, 16)
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("\(Int(trend.previousAvg))")
                            .font(.system(.title2, design: .rounded))
                            .fontWeight(.bold)
                        Text(trend.unit)
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundColor(.secondary)
                            .fontWeight(.medium)
                    }
                    Text("Prior 7 Days")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                }
            }
            .padding(.top, 4)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.secondaryBackground)
        )
        .padding(.horizontal)
    }
}
