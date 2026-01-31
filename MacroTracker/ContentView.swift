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

// 1. Mac Layout (Unchanged)
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
            switch selection {
            case .track: TrackerView()
            case .stats: StatsView()
            case .settings: SettingsView()
            case .none: Text("Select an item")
            }
        }
    }
}

// 2. iOS Layout (THE FIX IS HERE)
struct TabBarLayout: View {
    var body: some View {
        TabView {
            // FIX: Wrap TrackerView in NavigationView
            NavigationView {
                TrackerView()
            }
            .tabItem {
                Label("Track", systemImage: "list.bullet")
            }
            
            // FIX: Wrap StatsView in NavigationView
            NavigationView {
                StatsView()
            }
            .tabItem {
                Label("Stats", systemImage: "chart.bar.fill")
            }
            
            // FIX: Wrap SettingsView in NavigationView
            NavigationView {
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
