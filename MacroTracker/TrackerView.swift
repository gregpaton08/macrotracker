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
    @StateObject private var viewModel = MacroViewModel()
    @State private var inputText = ""
    @State private var showSettings = false
    
    // UPDATED: Fetch Meals, not individual foods
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \MealEntity.timestamp, ascending: false)],
        animation: .default)
    private var meals: FetchedResults<MealEntity>

    var body: some View {
        NavigationView {
            VStack {
                // Input Area
                HStack {
                    TextField("Describe meal...", text: $inputText)
                        .textFieldStyle(.roundedBorder)
                        .disabled(viewModel.isLoading)
                    
                    Button(action: {
                        Task {
                            await viewModel.processFoodEntry(text: inputText)
                            inputText = ""
                        }
                    }) {
                        if viewModel.isLoading { ProgressView() } else { Image(systemName: "arrow.up.circle.fill").font(.title2) }
                    }
                    .disabled(inputText.isEmpty || viewModel.isLoading)
                }
                .padding()
                
                if let error = viewModel.errorMessage {
                    Text(error).foregroundColor(.red).font(.caption)
                }

                // UPDATED: Hierarchical List
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
            }
            .navigationTitle("Log")
            .toolbar {
                Button(action: { showSettings.toggle() }) { Image(systemName: "gear") }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
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
