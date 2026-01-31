//
//  SettingsView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/30/26.
//

import SwiftUI

struct SettingsView: View {
    // API Keys
    @AppStorage("google_api_key") var googleKey: String = ""
    @AppStorage("usda_api_key") var usdaKey: String = ""
    
    // Goals
    @AppStorage("goal_p_min") var pMin: Double = 150
    @AppStorage("goal_p_max") var pMax: Double = 180
    @AppStorage("goal_c_min") var cMin: Double = 200
    @AppStorage("goal_c_max") var cMax: Double = 300
    @AppStorage("goal_f_min") var fMin: Double = 60
    @AppStorage("goal_f_max") var fMax: Double = 80
    
    var body: some View {
        // Remove NavigationView here if it's already in ContentView
        // If this is standalone, keep it. If nested in TabView > NavView, change to VStack or Group
        Form {
            // New Section: Database Management
            Section(header: Text("Data Management")) {
                NavigationLink(destination: SavedMealsView()) {
                    Label("Manage Saved Meals", systemImage: "archivebox")
                }
                NavigationLink("View Debug Logs", destination: LogViewer())
            }

            Section(header: Text("Protein Goals (g)")) {
                HStack {
                    TextField("Min", value: $pMin, format: .number)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                    Text("-")
                    TextField("Max", value: $pMax, format: .number)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }
            }
            
            Section(header: Text("Carb Goals (g)")) {
                HStack {
                    TextField("Min", value: $cMin, format: .number)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                    Text("-")
                    TextField("Max", value: $cMax, format: .number)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                }
            }
            
            Section(header: Text("Fat Goals (g)")) {
                HStack {
                    TextField("Min", value: $fMin, format: .number)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
                    Text("-")
                    TextField("Max", value: $fMax, format: .number)
                        #if os(iOS)
                        .keyboardType(.numberPad)
                        #endif
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
        // MARK: - THE FIX
        // Tapping anywhere on the form background dismisses keyboard
        .onTapGesture {
            #if os(iOS)
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            #endif
        }
    }
}
