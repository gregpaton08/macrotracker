//
//  ContentView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/25/26.
//
//  Root view of the app. Provides a four-tab TabView with each tab
//  wrapped in its own NavigationStack.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack { TrackerView() }
                .tabItem { Label("Tracker", systemImage: "fork.knife.circle.fill") }

            NavigationStack { InsightsView() }
                .tabItem { Label("Calendar", systemImage: "calendar.circle.fill") }

            NavigationStack { TrendsView() }
                .tabItem { Label("Trends", systemImage: "chart.bar.fill") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Theme.tint)
    }
}
