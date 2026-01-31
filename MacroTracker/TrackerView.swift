//
//  TrackerView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/28/26.
//
// This is the main view where you enter in food you ate and it shows a history of food items.

import SwiftUI
import CoreData

import SwiftUI
import CoreData

struct TrackerView: View {
    @StateObject private var viewModel = MacroViewModel()
    @State private var showSettings = false
    
    // NEW: Control the sheet
    @State private var showAddMeal = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MealEntity.timestamp, ascending: false)],
        animation: .default)
    private var meals: FetchedResults<MealEntity>

    var body: some View {
        NavigationView {
            List {
                ForEach(meals) { meal in
                    NavigationLink(destination: MealDetailView(meal: meal)) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(meal.summary ?? "Untitled Meal")
                                    .font(.headline)
                                Text(meal.timestamp ?? Date(), style: .time)
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("\(Int(meal.totalCalories)) kcal").bold()
                                Text("P:\(Int(meal.totalProtein)) C:\(Int(meal.totalCarbs)) F:\(Int(meal.totalFat))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .navigationTitle("Log")
            .toolbar {
                // Settings Button
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showSettings.toggle() }) {
                        Image(systemName: "gear")
                    }
                }
                
                // NEW: Add Meal Button
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddMeal.toggle() }) {
                        Image(systemName: "plus")
                    }
                }
            }
            // Bind the sheets
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showAddMeal) {
                // Pass the existing ViewModel so it shares API keys/logic
                AddMealView(viewModel: viewModel)
            }
        }
    }
    
    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { meals[$0] }.forEach(PersistenceController.shared.container.viewContext.delete)
            PersistenceController.shared.save()
        }
    }
}

struct SettingsView: View {
    // API Keys
    @AppStorage("google_api_key") var googleKey: String = ""
    @AppStorage("usda_api_key") var usdaKey: String = ""
    
    // Macro Goals (Default values provided)
    @AppStorage("goal_p_min") var pMin: Double = 150
    @AppStorage("goal_p_max") var pMax: Double = 180
    
    @AppStorage("goal_c_min") var cMin: Double = 200
    @AppStorage("goal_c_max") var cMax: Double = 300
    
    @AppStorage("goal_f_min") var fMin: Double = 60
    @AppStorage("goal_f_max") var fMax: Double = 80
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Protein Goals (g)")) {
                    HStack {
                        TextField("Min", value: $pMin, format: .number).keyboardType(.numberPad)
                        Text("-")
                        TextField("Max", value: $pMax, format: .number).keyboardType(.numberPad)
                    }
                }
                
                Section(header: Text("Carb Goals (g)")) {
                    HStack {
                        TextField("Min", value: $cMin, format: .number).keyboardType(.numberPad)
                        Text("-")
                        TextField("Max", value: $cMax, format: .number).keyboardType(.numberPad)
                    }
                }
                
                Section(header: Text("Fat Goals (g)")) {
                    HStack {
                        TextField("Min", value: $fMin, format: .number).keyboardType(.numberPad)
                        Text("-")
                        TextField("Max", value: $fMax, format: .number).keyboardType(.numberPad)
                    }
                }
                
                Section(header: Text("API Keys")) {
                    SecureField("Google Gemini Key", text: $googleKey)
                    SecureField("USDA API Key", text: $usdaKey)
                }
                
                Section(header: Text("Diagnostics")) {
                    NavigationLink("View Debug Logs", destination: LogViewer())
                }
            }
            .navigationTitle("Settings")
            .toolbar { Button("Done") { presentationMode.wrappedValue.dismiss() } }
        }
    }
}
