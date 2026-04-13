//
//  InteractivePopGesture.swift
//  Wingman
//

import SwiftUI
import UIKit

/// Re-enables the interactive pop (swipe-back) gesture on screens
/// that hide the navigation bar or back button.
struct InteractivePopGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        InteractivePopController()
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

private final class InteractivePopController: UIViewController {
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        navigationController?.interactivePopGestureRecognizer?.isEnabled = true
        navigationController?.interactivePopGestureRecognizer?.delegate = nil
    }
}

extension View {
    func enableInteractivePopGesture() -> some View {
        background(InteractivePopGestureEnabler())
    }
}
