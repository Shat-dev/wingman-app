//
//  InteractivePopGesture.swift
//  Wingman
//

import SwiftUI
import UIKit

/// Re-enables the interactive pop (swipe-back) gesture on screens
/// that hide the navigation bar or back button.
///
/// Design: the override is **scoped to the view's visible lifetime**.
/// On `viewWillAppear`, the helper captures the navigation controller's
/// original gesture-recognizer state (delegate + isEnabled), then applies
/// its own override (`delegate = nil`, `isEnabled = true`). On
/// `viewWillDisappear`, the original state is restored. This prevents the
/// override from leaking to sibling views on the same nav stack — a bug
/// that surfaced when AuthView's enabler persisted and caused
/// OnboardingView (pushed onto the same NavigationStack) to swipe-pop
/// back to LandingView instead of respecting its `.navigationBarBackButtonHidden(true)`.
struct InteractivePopGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        InteractivePopController()
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

private final class InteractivePopController: UIViewController {
    /// Captured on `viewWillAppear`, restored on `viewWillDisappear`.
    /// `weak` matches `UIGestureRecognizer.delegate`'s own weak semantics —
    /// we never keep the delegate alive longer than UIKit itself does.
    private weak var originalDelegate: UIGestureRecognizerDelegate?
    private var originalIsEnabled: Bool = true

    /// Tracks whether the override is currently applied so we don't
    /// re-capture our own nil'd state as the "original" on redundant
    /// lifecycle callbacks (e.g. viewDidAppear firing after a cancelled
    /// swipe-back, or viewWillAppear firing twice during a push animation).
    private var isOverrideActive: Bool = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyOverride()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Safety net for cancelled swipe-back: if the user starts an edge
        // swipe but releases before the threshold, iOS fires
        // viewWillDisappear (which restores the original delegate), then
        // viewDidAppear again. Re-applying here ensures swipe-back stays
        // functional on the next attempt. Idempotent via isOverrideActive.
        applyOverride()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        restoreOriginal()
    }

    private func applyOverride() {
        guard let recognizer = navigationController?.interactivePopGestureRecognizer else {
            return
        }
        // If already active, don't overwrite the captured "original" — our
        // own nil'd state would end up being captured, defeating the purpose.
        guard !isOverrideActive else { return }

        originalDelegate = recognizer.delegate
        originalIsEnabled = recognizer.isEnabled
        isOverrideActive = true

        recognizer.isEnabled = true
        recognizer.delegate = nil
    }

    private func restoreOriginal() {
        guard let recognizer = navigationController?.interactivePopGestureRecognizer else {
            return
        }
        guard isOverrideActive else { return }

        recognizer.delegate = originalDelegate
        recognizer.isEnabled = originalIsEnabled
        isOverrideActive = false
    }
}

extension View {
    func enableInteractivePopGesture() -> some View {
        background(InteractivePopGestureEnabler())
    }
}
