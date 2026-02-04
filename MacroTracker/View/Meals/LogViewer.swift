//
//  LogViewer.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/26/26.
//

// TODO: delete this file

import SwiftUI

struct LogViewer: View {
    @State private var logText: String = "Loading..."
    
    var body: some View {
        VStack {
            ScrollView {
                Text(logText)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled) // Allows text copying on iOS/macOS
            }
            .background(Color.gray.opacity(0.1))
            
            HStack {
                Button("Clear") {
                    Task {
//                        await LogStore.shared.clearLogs()
                        await loadLogs()
                    }
                }
                .foregroundColor(.red)
                
                Spacer()
                
                Button("Refresh") {
                    Task { await loadLogs() }
                }
                
                Spacer()
                
                // MARK: - THE FIX (Cross-Platform Export)
                // ShareLink works natively on iOS and macOS (no UIKit needed)
//                ShareLink(item: LogStore.shared.fileURL) {
//                    Label("Export", systemImage: "square.and.arrow.up")
//                }
            }
            .padding()
        }
        .navigationTitle("System Logs")
        .onAppear {
            Task { await loadLogs() }
        }
    }
    
    private func loadLogs() async {
//        logText = await LogStore.shared.readLogs()
    }
}

// Note: You can now DELETE the 'ShareSheet' struct and 'LogFileProvider' class.
// They are obsolete with ShareLink.
