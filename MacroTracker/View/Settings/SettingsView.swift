//
//  SettingsView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/30/26.
//

import SwiftUI

struct SettingsView: View {
    // API Keys & Goals
    @AppStorage("google_api_key") var googleKey: String = ""
    @AppStorage("usda_api_key") var usdaKey: String = ""
    @AppStorage("goal_f_min") var fMin: Double = 60
    @AppStorage("goal_f_max") var fMax: Double = 80
    @AppStorage("goal_c_min") var cMin: Double = 200
    @AppStorage("goal_c_max") var cMax: Double = 300
    @AppStorage("goal_p_min") var pMin: Double = 150
    @AppStorage("goal_p_max") var pMax: Double = 180
    
    // Import/Export State
    @State private var showFileImporter = false
    @State private var importAlertMessage = ""
    @State private var showImportAlert = false
    
    // We generate the URL on demand
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
            
            // MARK: - NEW: Import / Export
            Section(header: Text("Backup & Restore")) {
                // Export
                if let url = exportURL {
                    ShareLink(item: url, preview: SharePreview("MacroTracker Data", image: Image(systemName: "chart.pie.fill"))) {
                        Label("Export Data to JSON", systemImage: "square.and.arrow.up")
                    }
                }
                
                // Import
                Button(action: { showFileImporter = true }) {
                    Label("Import Data from JSON", systemImage: "square.and.arrow.down")
                }
            }
            
            // ... (Goal Sections) ...
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
            
            Section(header: Text("API Keys")) {
                SecureField("Google Gemini Key", text: $googleKey)
                SecureField("USDA API Key", text: $usdaKey)
            }
            
            Section(header: Text("Links")) {
                Link("Get Google Key", destination: URL(string: "https://aistudio.google.com/app/apikey")!)
                Link("Get USDA Key", destination: URL(string: "https://api.data.gov/signup/")!)
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
            Button("OK", role: .cancel) { }
        } message: {
            Text(importAlertMessage)
        }
    }
}
