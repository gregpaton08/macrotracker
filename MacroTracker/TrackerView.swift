//
//  TrackerView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/28/26.
//

import SwiftUI
import CoreData

// ⚠️ THIS IS YOUR OLD "ContentView" RENAMED
struct TrackerView: View {
    @StateObject private var viewModel = MacroViewModel()
    @State private var inputText = ""
    @State private var showSettings = false
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \FoodEntity.timestamp, ascending: false)],
        animation: .default)
    private var foods: FetchedResults<FoodEntity>

    var body: some View {
        NavigationView {
            VStack {
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

                List {
                    ForEach(foods) { food in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(food.name ?? "Unknown").font(.headline)
                                Text("\(Int(food.weightGrams))g").font(.caption).foregroundColor(.gray)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("\(Int(food.calories)) kcal").bold()
                                Text("P: \(Int(food.protein)) C: \(Int(food.carbs)) F: \(Int(food.fat))")
                                    .font(.caption).foregroundColor(.secondary)
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
            offsets.map { foods[$0] }.forEach(PersistenceController.shared.container.viewContext.delete)
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
