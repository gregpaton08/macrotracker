////
////  Logger.swift
////  MacroTracker
////
////  Created by Gregory Paton on 1/26/26.
////
//
//import Foundation
//
//enum LogCategory: String {
//    case gemini   = "🤖 [Gemini]"
//    case usda     = "🥦 [USDA]"
//    case coreData = "💾 [Persistence]"
//    case ui       = "📱 [UI]"
//}
//
//enum LogLevel: String {
//    case info  = "ℹ️"
//    case warn  = "⚠️"
//    case error = "🛑"
//    case success = "✅"
//}
//
//// THE ACTOR (Thread-Safe File Writer)
//actor LogStore {
//    static let shared = LogStore()
//    
//    // Non-isolated so we can read it synchronously
//    nonisolated let fileURL: URL
//    
//    // 1. FIX: Create a standard formatter for "HH:mm:ss.SSS"
//    private let dateFormatter: DateFormatter = {
//        let df = DateFormatter()
//        df.dateFormat = "HH:mm:ss.SSS"
//        return df
//    }()
//    
//    private init() {
//        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
//        fileURL = paths[0].appendingPathComponent("debug_logs.txt")
//        
//        if !FileManager.default.fileExists(atPath: fileURL.path) {
//            try? "".write(to: fileURL, atomically: true, encoding: .utf8)
//        }
//    }
//    
//    func append(_ message: String) {
//        // 2. FIX: Use the formatter here
//        let timestamp = dateFormatter.string(from: Date())
//        let logLine = "\(timestamp) > \(message)\n"
//        
//        if let data = logLine.data(using: .utf8),
//           let handle = try? FileHandle(forWritingTo: fileURL) {
//            handle.seekToEndOfFile()
//            handle.write(data)
//            try? handle.close()
//        }
//    }
//    
//    func readLogs() -> String {
//        return (try? String(contentsOf: fileURL)) ?? "No logs found."
//    }
//    
//    func clearLogs() {
//        try? "".write(to: fileURL, atomically: true, encoding: .utf8)
//    }
//}
//
//// THE PUBLIC INTERFACE
//struct Logger {
//    static func log(_ message: String, category: LogCategory, level: LogLevel = .info) {
//        let msg = "\(category.rawValue) \(level.rawValue) :: \(message)"
//        print(msg) // Xcode Console
//        Task { await LogStore.shared.append(msg) } // Disk
//    }
//    
//    static func logResponse(data: Data?, response: URLResponse?, error: Error?, category: LogCategory) {
//        if let error = error {
//            log("Req Failed: \(error.localizedDescription)", category: category, level: .error)
//            return
//        }
//        guard let httpResponse = response as? HTTPURLResponse else { return }
//        
//        let level: LogLevel = (200...299).contains(httpResponse.statusCode) ? .success : .error
//        log("Status: \(httpResponse.statusCode)", category: category, level: level)
//        
//        if let data = data, let str = String(data: data, encoding: .utf8) {
//             log("Body: \(str)", category: category, level: .error)
//        }
//    }
//}
