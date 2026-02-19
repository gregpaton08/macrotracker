//
//  BarcodeScannerView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/18/26.
//

import SwiftUI
import VisionKit

struct BarcodeScannerView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    var onResult: (String) -> Void
    
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }
    
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if !uiViewController.isScanning {
            try? uiViewController.startScanning()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let parent: BarcodeScannerView
        var isProcessing = false
        
        init(_ parent: BarcodeScannerView) {
            self.parent = parent
        }
        
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            processItem(item)
        }
        
        // Auto-detect without tapping
        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard let item = addedItems.first else { return }
            processItem(item)
        }
        
        private func processItem(_ item: RecognizedItem) {
            guard !isProcessing else { return }
            
            switch item {
            case .barcode(let code):
                guard let value = code.payloadStringValue else { return }
                isProcessing = true
                parent.onResult(value)
                parent.presentationMode.wrappedValue.dismiss()
            default:
                break
            }
        }
    }
}
