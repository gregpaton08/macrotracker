//
//  MacroTrackerApp.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/25/26.
//

import SwiftUI

@main
struct MacroTrackerApp: App {
    // Initialize the persistence controller (CloudKit + CoreData)
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                // INJECT THE CONTEXT HERE
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
