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
    @Environment(\.managedObjectContext) var viewContext
    
    // MARK: - Persisted Settings (Legacy Fallbacks)

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
        ("gemini-1.5-flash", "Gemini 1.5 Flash")
    ]
    
    // These are now only used for fallback/initial migration
    @AppStorage("goal_f_min") var legacyFMin: Double = 60
    @AppStorage("goal_f_max") var legacyFMax: Double = 80
    @AppStorage("goal_c_min") var legacyCMin: Double = 200
    @AppStorage("goal_c_max") var legacyCMax: Double = 300
    @AppStorage("goal_p_min") var legacyPMin: Double = 150
    @AppStorage("goal_p_max") var legacyPMax: Double = 180

    // MARK: - Body Profile & g/kg Goals

    @AppStorage("bodyweight") var legacyBodyweight: Double = 180
    @AppStorage("bodyweight_unit") var legacyBodyweightUnit: String = "lbs"

    @AppStorage("goal_f_mode") var legacyFMode: String = "grams"
    @AppStorage("goal_f_min_g_kg") var legacyFMinGKg: Double = 0.8
    @AppStorage("goal_f_max_g_kg") var legacyFMaxGKg: Double = 1.0

    @AppStorage("goal_c_mode") var legacyCMode: String = "grams"
    @AppStorage("goal_c_min_g_kg") var legacyCMinGKg: Double = 2.0
    @AppStorage("goal_c_max_g_kg") var legacyCMaxGKg: Double = 3.0

    @AppStorage("goal_p_mode") var legacyPMode: String = "grams"
    @AppStorage("goal_p_min_g_kg") var legacyPMinGKg: Double = 1.8
    @AppStorage("goal_p_max_g_kg") var legacyPMaxGKg: Double = 2.2

    // Local state for editing - initialized from DailyGoalEntity
    @State private var fMin: Double = 60
    @State private var fMax: Double = 80
    @State private var cMin: Double = 200
    @State private var cMax: Double = 300
    @State private var pMin: Double = 150
    @State private var pMax: Double = 180
    @State private var bodyweight: Double = 180
    @State private var bodyweightUnit: String = "lbs"
    @State private var fMode: String = "grams"
    @State private var fMinGKg: Double = 0.8
    @State private var fMaxGKg: Double = 1.0
    @State private var cMode: String = "grams"
    @State private var cMinGKg: Double = 2.0
    @State private var cMaxGKg: Double = 3.0
    @State private var pMode: String = "grams"
    @State private var pMinGKg: Double = 1.8
    @State private var pMaxGKg: Double = 2.2

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

    private func loadGoals() {
        if let currentGoal = DailyGoalEntity.goal(for: Date(), context: viewContext) {
            bodyweight = currentGoal.bodyweight
            bodyweightUnit = currentGoal.bodyweightUnit ?? "lbs"
            fMin = currentGoal.fMin
            fMax = currentGoal.fMax
            fMode = currentGoal.fMode ?? "grams"
            fMinGKg = currentGoal.fMinGKg
            fMaxGKg = currentGoal.fMaxGKg
            cMin = currentGoal.cMin
            cMax = currentGoal.cMax
            cMode = currentGoal.cMode ?? "grams"
            cMinGKg = currentGoal.cMinGKg
            cMaxGKg = currentGoal.cMaxGKg
            pMin = currentGoal.pMin
            pMax = currentGoal.pMax
            pMode = currentGoal.pMode ?? "grams"
            pMinGKg = currentGoal.pMinGKg
            pMaxGKg = currentGoal.pMaxGKg
        } else {
            // Migration from legacy AppStorage
            bodyweight = legacyBodyweight
            bodyweightUnit = legacyBodyweightUnit
            fMin = legacyFMin
            fMax = legacyFMax
            fMode = legacyFMode
            fMinGKg = legacyFMinGKg
            fMaxGKg = legacyFMaxGKg
            cMin = legacyCMin
            cMax = legacyCMax
            cMode = legacyCMode
            cMinGKg = legacyCMinGKg
            cMaxGKg = legacyCMaxGKg
            pMin = legacyPMin
            pMax = legacyPMax
            pMode = legacyPMode
            pMinGKg = legacyPMinGKg
            pMaxGKg = legacyPMaxGKg
            
            saveGoalToCoreData()
        }
    }

    private func recalculateGoals() {
        let weightInKg = bodyweightUnit == "kg" ? bodyweight : bodyweight / 2.20462

        if fMode == "g_kg" {
            fMin = (fMinGKg * weightInKg).rounded()
            fMax = (fMaxGKg * weightInKg).rounded()
        }
        if cMode == "g_kg" {
            cMin = (cMinGKg * weightInKg).rounded()
            cMax = (cMaxGKg * weightInKg).rounded()
        }
        if pMode == "g_kg" {
            pMin = (pMinGKg * weightInKg).rounded()
            pMax = (pMaxGKg * weightInKg).rounded()
        }
    }
    
    private func saveGoalToCoreData() {
        DailyGoalEntity.updateGoal(
            for: Date(),
            in: viewContext,
            bodyweight: bodyweight,
            bodyweightUnit: bodyweightUnit,
            fMin: fMin,
            fMax: fMax,
            cMin: cMin,
            cMax: cMax,
            pMin: pMin,
            pMax: pMax,
            fMode: fMode,
            fMinGKg: fMinGKg,
            fMaxGKg: fMaxGKg,
            cMode: cMode,
            cMinGKg: cMinGKg,
            cMaxGKg: cMaxGKg,
            pMode: pMode,
            pMinGKg: pMinGKg,
            pMaxGKg: pMaxGKg
        )
    }

    var body: some View {
        Form {
            Section(header: Text("Data Management")) {
                NavigationLink(destination: SavedMealsView()) {
                    Label("Manage Saved Meals", systemImage: "archivebox")
                }
            }

            Section(header: Text("Body Profile")) {
                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("Weight", value: $bodyweight, format: .number)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                    Picker("Unit", selection: $bodyweightUnit) {
                        Text("lbs").tag("lbs")
                        Text("kg").tag("kg")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 90)
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
            Section(header: Text("Fat Goals")) {
                Picker("Mode", selection: $fMode) {
                    Text("Grams").tag("grams")
                    Text("g/kg").tag("g_kg")
                }
                .pickerStyle(.segmented)

                if fMode == "grams" {
                    HStack {
                        TextField("Min", value: $fMin, format: .number)
                        Text("-")
                        TextField("Max", value: $fMax, format: .number)
                        Text("g")
                    }
                } else {
                    HStack {
                        TextField("Min", value: $fMinGKg, format: .number)
                        Text("-")
                        TextField("Max", value: $fMaxGKg, format: .number)
                        Text("g/kg")
                    }
                    Text("Result: \(Int(fMin)) - \(Int(fMax)) g")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Carb Goals")) {
                Picker("Mode", selection: $cMode) {
                    Text("Grams").tag("grams")
                    Text("g/kg").tag("g_kg")
                }
                .pickerStyle(.segmented)

                if cMode == "grams" {
                    HStack {
                        TextField("Min", value: $cMin, format: .number)
                        Text("-")
                        TextField("Max", value: $cMax, format: .number)
                        Text("g")
                    }
                } else {
                    HStack {
                        TextField("Min", value: $cMinGKg, format: .number)
                        Text("-")
                        TextField("Max", value: $cMaxGKg, format: .number)
                        Text("g/kg")
                    }
                    Text("Result: \(Int(cMin)) - \(Int(cMax)) g")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(header: Text("Protein Goals")) {
                Picker("Mode", selection: $pMode) {
                    Text("Grams").tag("grams")
                    Text("g/kg").tag("g_kg")
                }
                .pickerStyle(.segmented)

                if pMode == "grams" {
                    HStack {
                        TextField("Min", value: $pMin, format: .number)
                        Text("-")
                        TextField("Max", value: $pMax, format: .number)
                        Text("g")
                    }
                } else {
                    HStack {
                        TextField("Min", value: $pMinGKg, format: .number)
                        Text("-")
                        TextField("Max", value: $pMaxGKg, format: .number)
                        Text("g/kg")
                    }
                    Text("Result: \(Int(pMin)) - \(Int(pMax)) g")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
        .onAppear(perform: loadGoals)
        .onChange(of: bodyweight) { _ in recalculateGoals(); saveGoalToCoreData() }
        .onChange(of: bodyweightUnit) { _ in recalculateGoals(); saveGoalToCoreData() }
        .onChange(of: fMode) { _ in recalculateGoals(); saveGoalToCoreData() }
        .onChange(of: fMin) { _ in saveGoalToCoreData() }
        .onChange(of: fMax) { _ in saveGoalToCoreData() }
        .onChange(of: fMinGKg) { _ in recalculateGoals(); saveGoalToCoreData() }
        .onChange(of: fMaxGKg) { _ in recalculateGoals(); saveGoalToCoreData() }
        .onChange(of: cMode) { _ in recalculateGoals(); saveGoalToCoreData() }
        .onChange(of: cMin) { _ in saveGoalToCoreData() }
        .onChange(of: cMax) { _ in saveGoalToCoreData() }
        .onChange(of: cMinGKg) { _ in recalculateGoals(); saveGoalToCoreData() }
        .onChange(of: cMaxGKg) { _ in recalculateGoals(); saveGoalToCoreData() }
        .onChange(of: pMode) { _ in recalculateGoals(); saveGoalToCoreData() }
        .onChange(of: pMin) { _ in saveGoalToCoreData() }
        .onChange(of: pMax) { _ in saveGoalToCoreData() }
        .onChange(of: pMinGKg) { _ in recalculateGoals(); saveGoalToCoreData() }
        .onChange(of: pMaxGKg) { _ in recalculateGoals(); saveGoalToCoreData() }
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
