//
//  LogViewer.swift
//  MacroTracker
//
//  Created by Gregory Paton on 1/26/26.
//

import SwiftUI

struct LogViewer: View {
    @State private var logText: String = "Loading..."
    @State private var showShareSheet = false
    
    var body: some View {
        VStack {
            ScrollView {
                Text(logText)
                    .font(.system(.caption, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color(UIColor.systemGray6))
            
            HStack {
                Button("Clear") {
                    Task {
                        await LogStore.shared.clearLogs()
                        await loadLogs()
                    }
                }
                .foregroundColor(.red)
                Spacer()
                Button("Refresh") { Task { await loadLogs() } }
                Spacer()
                Button(action: { showShareSheet = true }) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export")
                }
            }
            .padding()
        }
        .navigationTitle("System Logs")
        .onAppear { Task { await loadLogs() } }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [LogFileProvider()])
        }
    }
    
    private func loadLogs() async {
        logText = await LogStore.shared.readLogs()
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        return UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

class LogFileProvider: NSObject, UIActivityItemSource {
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return ""
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        // FIX: Access the nonisolated property directly. No Task needed.
        return LogStore.shared.fileURL
    }
}
