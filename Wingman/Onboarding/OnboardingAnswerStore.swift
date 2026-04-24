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

    /// Record an answer for a question. Writes to the in-memory dict
    /// synchronously (so SwiftUI observers see the new value immediately)
    /// and persists to UserDefaults on a background queue.
    func setAnswer(_ value: String, forKey key: String) {
        answers[key] = value
        DispatchQueue.global(qos: .utility).async {
            UserDefaults.standard.set(value, forKey: "onboarding_\(key)")
            log("✅ Saved answer:", key, value)
        }
    }
}
