//
//  OnboardingAnswerStore.swift
//  Wingman
//
//  Owns the in-memory answer dictionary for the onboarding flow and
//  persists each answer to UserDefaults under the `onboarding_<key>` scheme
//  that the rest of the app expects.
//
//  The UserDefaults write is dispatched to a background utility queue so
//  the disk-touching I/O doesn't block the tap→slide-animation path on
//  older devices. `UserDefaults.standard.set` is documented thread-safe,
//  and no code anywhere reads these keys synchronously — they exist purely
//  for potential resume-after-kill scenarios — so a deferred write is
//  invisible to every consumer. The in-memory `answers` dict remains the
//  source of truth for all read-after-write access within the flow.
//

import Foundation
import Combine

final class OnboardingAnswerStore: ObservableObject {
    @Published var answers: [String: String] = [:]

    /// Serial, so writes and removals for the same key land in the order
    /// they were requested. `DispatchQueue.global()` is concurrent and gave
    /// no such guarantee — harmless while every answer was write-once, but
    /// `clearAnswer` makes set-then-clear a real sequence (type a name,
    /// swipe back, skip) whose outcome must not depend on scheduling.
    private let ioQueue = DispatchQueue(label: "com.wingman.onboarding-answers", qos: .utility)

    /// Record an answer for a question. Writes to the in-memory dict
    /// synchronously (so SwiftUI observers see the new value immediately)
    /// and persists to UserDefaults on a background queue.
    func setAnswer(_ value: String, forKey key: String) {
        answers[key] = value
        ioQueue.async {
            UserDefaults.standard.set(value, forKey: "onboarding_\(key)")
            log("✅ Saved answer:", key, value)
        }
    }

    /// Forget an answer entirely, in memory and on disk.
    ///
    /// Exists for the one question that can be left unanswered: the name.
    /// A user can type a name, continue, swipe back and then skip — without
    /// this, the earlier value would survive in both stores and the pact
    /// would still address them by a name they just declined to give.
    ///
    /// Removal is dispatched on the same queue as `setAnswer`'s write so a
    /// set immediately followed by a clear cannot land out of order.
    func clearAnswer(forKey key: String) {
        answers[key] = nil
        ioQueue.async {
            UserDefaults.standard.removeObject(forKey: "onboarding_\(key)")
            log("🧹 Cleared answer:", key)
        }
    }
}
