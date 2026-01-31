//
//  ContentView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/25/26.
//

import SwiftUI

struct ContentView: View {
    #if os(iOS)
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    #endif

    var body: some View {
        #if os(macOS)
        SidebarLayout()
        #else
        TabBarLayout()
        #endif
    }
}

// MARK: - Mac Layout
struct SidebarLayout: View {
    @State private var selection: TabSelection? = .track
    
    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                NavigationLink(value: TabSelection.track) {
                    Label("Track", systemImage: "list.bullet")
                }
                NavigationLink(value: TabSelection.stats) {
                    Label("Stats", systemImage: "chart.bar.fill")
                }
                NavigationLink(value: TabSelection.settings) {
                    Label("Settings", systemImage: "gear")
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("Macro Tracker")
        } detail: {
            // FIX: Wrap the destination in NavigationStack so links inside (like SavedMeals) work
            NavigationStack {
                switch selection {
                case .track: TrackerView()
                case .stats: StatsView()
                case .settings: SettingsView()
                case .none: Text("Select an item")
                }
            }
        }
    }
}

// MARK: - iOS Layout
struct TabBarLayout: View {
    var body: some View {
        TabView {
            // FIX: Use NavigationStack instead of NavigationView (it is more robust on iOS 16+)
            NavigationStack {
                TrackerView()
            }
            .tabItem {
                Label("Track", systemImage: "list.bullet")
            }
            
            NavigationStack {
                StatsView()
            }
            .tabItem {
                Label("Stats", systemImage: "chart.bar.fill")
            }
            
            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
    }
}

enum TabSelection {
    case track, stats, settings
}
