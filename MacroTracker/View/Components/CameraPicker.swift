//
//  CameraPicker.swift
//  MacroTracker
//
//  SwiftUI wrapper around UIImagePickerController for taking photos
//  or selecting images from the photo library. Dismissal is driven
//  by the `isPresented` binding so SwiftUI manages the sheet lifecycle.
//

import SwiftUI
import UIKit

struct CameraPicker: UIViewControllerRepresentable {
  let sourceType: UIImagePickerController.SourceType
  /// Bound to the parent's sheet state; set to `false` to dismiss.
  @Binding var isPresented: Bool
  /// Called with the selected image after the user picks or captures a photo.
  var onImagePicked: (UIImage) -> Void

  func makeUIViewController(context: Context) -> UIImagePickerController {
    let picker = UIImagePickerController()
    picker.sourceType = sourceType
    picker.delegate = context.coordinator
    return picker
  }

  func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

  func makeCoordinator() -> Coordinator {
    Coordinator(isPresented: $isPresented, onImagePicked: onImagePicked)
  }

  /// Bridges UIImagePickerController delegate callbacks to SwiftUI.
  class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    @Binding var isPresented: Bool
    let onImagePicked: (UIImage) -> Void

    init(isPresented: Binding<Bool>, onImagePicked: @escaping (UIImage) -> Void) {
      self._isPresented = isPresented
      self.onImagePicked = onImagePicked
    }

    func imagePickerController(
      _ picker: UIImagePickerController,
      didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
      if let image = info[.originalImage] as? UIImage {
        onImagePicked(image)
      }
      isPresented = false
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
      isPresented = false
    }
  }
}
