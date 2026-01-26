//
//  MacroTrackerApp.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/25/26.
//

import SwiftUI

@main
struct MacroTrackerApp: App {
    // 1. Initialize the persistence controller
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                // 2. INJECT THE CONTEXT HERE
                // This line fixes the error:
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
