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
            // Tab 1: The Input
            TrackerView()
                .tabItem {
                    Label("Track", systemImage: "list.bullet")
                }
            
            // Tab 2: The Stats
            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
        }
    }
}
