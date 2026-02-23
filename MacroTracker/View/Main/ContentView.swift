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
        .tabItem { Label("Tracker", systemImage: "fork.knife") }

      NavigationStack { InsightsView() }
        .tabItem { Label("Calendar", systemImage: "calendar") }

      NavigationStack { TrendsView() }
        .tabItem { Label("Trends", systemImage: "chart.line.uptrend.xyaxis") }

      NavigationStack { SettingsView() }
        .tabItem { Label("Settings", systemImage: "gearshape") }
    }
    .tint(Theme.tint)
  }
}
