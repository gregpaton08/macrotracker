import SwiftUI
import Charts
import CoreData

struct StatsView: View {
    @State private var selectedDate = Date()
    
    var body: some View {
        NavigationView {
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
            .navigationBarTitleDisplayMode(.inline)
        }
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
    
    // We initialize the FetchRequest inside init based on the passed date
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
            if todaysFoods.isEmpty {
                Spacer()
                Text("No data for this day").foregroundColor(.gray)
                Spacer()
            } else {
                Chart(totals) { item in
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
                .frame(height: 300)
                .padding()
            }
            
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
