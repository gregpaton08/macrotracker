//
//  SettingsView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/30/26.
//
//  App-wide settings screen.
//  Sections: Saved Meals management, Backup/Restore (JSON import/export),
//  macro goal ranges (Fat, Carbs, Protein min/max), and API key entry.
//

import SwiftUI

struct SettingsView: View {
    // MARK: - Persisted Settings
    
    // AI Configuration
    @AppStorage("use_aws_proxy") var useAWSProxy: Bool = false
    @AppStorage("aws_proxy_url") var awsProxyURL: String = ""
    @AppStorage("google_api_key") var googleKey: String = ""
    @AppStorage("gemini_model") var geminiModel: String = "gemini-2.0-flash"

    private let geminiModels: [(id: String, name: String)] = [
        ("gemini-3-flash-preview", "Gemini 3 Flash Preview"),
        ("gemini-2.5-pro-preview", "Gemini 2.5 Pro"),
        ("gemini-2.0-flash", "Gemini 2.0 Flash"),
        ("gemini-2.0-flash-lite", "Gemini 2.0 Flash Lite"),
        ("gemini-1.5-pro", "Gemini 1.5 Pro"),
        ("gemini-1.5-flash", "Gemini 1.5 Flash"),
    ]
    @AppStorage("goal_f_min") var fMin: Double = 60
    @AppStorage("goal_f_max") var fMax: Double = 80
    @AppStorage("goal_c_min") var cMin: Double = 200
    @AppStorage("goal_c_max") var cMax: Double = 300
    @AppStorage("goal_p_min") var pMin: Double = 150
    @AppStorage("goal_p_max") var pMax: Double = 180

    // MARK: - Energy Source

    @AppStorage("energy_source") var energySource: String = "active"
    @AppStorage("show_workouts_total_energy") var showWorkoutsInTotalMode: Bool = false

    // MARK: - Workout Type Filters

    @AppStorage("workout_filter_run") var filterRun: Bool = true
    @AppStorage("workout_filter_cycle") var filterCycle: Bool = true
    @AppStorage("workout_filter_walk") var filterWalk: Bool = true
    @AppStorage("workout_filter_strength") var filterStrength: Bool = true
    @AppStorage("workout_filter_hiit") var filterHIIT: Bool = true
    @AppStorage("workout_filter_yoga") var filterYoga: Bool = true
    @AppStorage("workout_filter_swim") var filterSwim: Bool = true
    @AppStorage("workout_filter_other") var filterOther: Bool = true

    // MARK: - Import/Export State

    @State private var showFileImporter = false
    @State private var importAlertMessage = ""
    @State private var showImportAlert = false

    /// Generates a temporary JSON export file URL on demand for the ShareLink.
    var exportURL: URL? {
        DataTransferManager.shared.generateJSON()
    }

    var body: some View {
        Form {
            Section(header: Text("Data Management")) {
                NavigationLink(destination: SavedMealsView()) {
                    Label("Manage Saved Meals", systemImage: "archivebox")
                }
            }

            Section(
                header: Text("Energy Source"),
                footer: Text(
                    energySource == "total"
                        ? "Total Energy includes active + resting (basal) calories."
                        : "Active Energy shows only calories from movement and exercise.")
            ) {
                Picker("Energy Source", selection: $energySource) {
                    Text("Active Energy").tag("active")
                    Text("Total Energy").tag("total")
                }
                if energySource == "total" {
                    Toggle("Show Workouts", isOn: $showWorkoutsInTotalMode)
                }
            }

            Section(
                header: Text("Workout Types"),
                footer: Text("Disabled types are hidden and excluded from burned calories.")
            ) {
                Toggle("Run", isOn: $filterRun)
                Toggle("Cycle", isOn: $filterCycle)
                Toggle("Walk", isOn: $filterWalk)
                Toggle("Strength", isOn: $filterStrength)
                Toggle("HIIT", isOn: $filterHIIT)
                Toggle("Yoga", isOn: $filterYoga)
                Toggle("Swim", isOn: $filterSwim)
                Toggle("Other", isOn: $filterOther)
            }
            
            // Goals Sections
            Section(header: Text("Fat Goals (g)")) {
                HStack {
                    TextField("Min", value: $fMin, format: .number)
                    Text("-")
                    TextField("Max", value: $fMax, format: .number)
                }
            }
            Section(header: Text("Carb Goals (g)")) {
                HStack {
                    TextField("Min", value: $cMin, format: .number)
                    Text("-")
                    TextField("Max", value: $cMax, format: .number)
                }
            }
            Section(header: Text("Protein Goals (g)")) {
                HStack {
                    TextField("Min", value: $pMin, format: .number)
                    Text("-")
                    TextField("Max", value: $pMax, format: .number)
                }
            }
            
            Section(
                header: Text("AI Configuration"),
                footer: Text("Toggle off to use your local API key. Toggle on to route through your secure backend proxy.")
            ) {
                Toggle("Use AWS Proxy Backend", isOn: $useAWSProxy)
                
                TextField("AWS Proxy URL (e.g. .../analyze)", text: $awsProxyURL)
                    .keyboardType(.URL)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            }

            Section(header: Text("Gemini API Key")) {
                SecureField("Google Gemini Key", text: $googleKey)
                Picker("Model", selection: $geminiModel) {
                    ForEach(geminiModels, id: \.id) { model in
                        Text(model.name).tag(model.id)
                    }
                }
            }

            // MARK: - Import / Export
            Section(header: Text("Backup & Restore")) {
                // Export
                if let url = exportURL {
                    ShareLink(
                        item: url,
                        preview: SharePreview(
                            "MacroTracker Data", image: Image(systemName: "chart.pie.fill"))
                    ) {
                        Label("Export Data to JSON", systemImage: "square.and.arrow.up")
                    }
                }

                // Import
                Button(action: { showFileImporter = true }) {
                    Label("Import Data from JSON", systemImage: "square.and.arrow.down")
                }
            }
        }
        .navigationTitle("Settings")
        #if os(iOS)
            .scrollDismissesKeyboard(.immediately)
        #endif

        // MARK: - Import Logic Handlers
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                Task {
                    do {
                        let count = try await DataTransferManager.shared.importJSON(from: url)
                        importAlertMessage = "Successfully imported \(count) new meals."
                        showImportAlert = true
                    } catch {
                        importAlertMessage = "Import failed: \(error.localizedDescription)"
                        showImportAlert = true
                    }
                }
            case .failure(let error):
                importAlertMessage = "Error selecting file: \(error.localizedDescription)"
                showImportAlert = true
            }
        }
        .alert("Import Status", isPresented: $showImportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importAlertMessage)
        }
    }
}
