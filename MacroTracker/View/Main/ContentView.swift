//
//  ContentView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/25/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        // Single Navigation Stack for the whole app
        NavigationStack {
            TrackerView()
        }
        .tint(Theme.tint) // Applies global blue tint
    }
}
