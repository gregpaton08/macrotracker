//
//  MacroTrackerApp.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/25/26.
//

import SwiftUI

@main
struct MacroTrackerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            if let error = persistenceController.loadError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)
                    Text("Unable to Load Data")
                        .font(.title2).bold()
                    Text("MacroTracker could not open its database. Try restarting the app or freeing up storage.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                ContentView()
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }
        }
    }
}
