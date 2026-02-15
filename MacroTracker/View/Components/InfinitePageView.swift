//
//  InfinitePageView.swift
//  MacroTracker
//
//  Created by Gregory Paton on 2/14/26.
//

import SwiftUI
import UIKit

struct InfinitePageView<Content: View>: UIViewControllerRepresentable {
    @Binding var selection: Int
    let content: (Int) -> Content

    @Environment(\.managedObjectContext) var context

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pageViewController = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal
        )
        pageViewController.dataSource = context.coordinator
        pageViewController.delegate = context.coordinator
        pageViewController.view.backgroundColor = .clear

        // Initial Setup
        let initialVC = context.coordinator.controller(for: selection)
        pageViewController.setViewControllers([initialVC], direction: .forward, animated: false)

        return pageViewController
    }

    func updateUIViewController(_ pageViewController: UIPageViewController, context: Context) {
        context.coordinator.parent = self

        // Check if the current view on screen matches the SwiftUI 'selection' state
        guard let currentVC = pageViewController.viewControllers?.first as? IndexedHostingController else { return }

        if currentVC.index != selection {
            // The state changed (e.g. User tapped Arrow or Calendar)
            // We must force the PageViewController to scroll to the new index
            let direction: UIPageViewController.NavigationDirection = selection > currentVC.index ? .forward : .reverse
            let newVC = context.coordinator.controller(for: selection)

            // NOTE: animated: true enables the sliding animation for arrows
            pageViewController.setViewControllers([newVC], direction: direction, animated: true)
        }
    }

    class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: InfinitePageView

        init(_ parent: InfinitePageView) {
            self.parent = parent
        }

        // Create a HostingController for a specific index
        func controller(for index: Int) -> UIViewController {
            let view = AnyView(
                parent.content(index)
                    .environment(\.managedObjectContext, parent.context)
            )

            let controller = IndexedHostingController(rootView: view)
            controller.index = index
            controller.view.backgroundColor = .clear
            return controller
        }

        // MARK: - DataSource (Swipe Logic)

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let currentVC = viewController as? IndexedHostingController else { return nil }
            return controller(for: currentVC.index - 1)
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let currentVC = viewController as? IndexedHostingController else { return nil }
            return controller(for: currentVC.index + 1)
        }

        // MARK: - Delegate (State Sync)

        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            if completed,
               let visibleVC = pageViewController.viewControllers?.first as? IndexedHostingController {
                // IMPORTANT: Tell SwiftUI that the user swiped to a new index
                // We do this async to avoid modifying state during view update
                DispatchQueue.main.async {
                    self.parent.selection = visibleVC.index
                }
            }
        }
    }
}

// Non-generic hosting controller so casts always succeed regardless of view type
class IndexedHostingController: UIHostingController<AnyView> {
    var index: Int = 0
}
