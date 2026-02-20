//
//  ContentView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/25/26.
//
//  Root view of the app. Wraps TrackerView in a single NavigationStack
//  and applies the global tint color.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            TrackerView()
        }
        .tint(Theme.tint)
    }
}
