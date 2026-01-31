//
//  ContentView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/25/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            // Tab 1: Tracker
            TrackerView()
                .tabItem {
                    Label("Track", systemImage: "list.bullet")
                }
            
            // Tab 2: Stats
            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
            
            // Tab 3: Settings (Now its own tab!)
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
