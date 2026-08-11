//
//  OnboardingName.swift
//  Wingman
//
//  One definition of the optional name collected on the first onboarding
//  screen: where it is stored, what counts as a usable value, and how every
//  reader gets at it.
//
//  It lives apart from `OnboardingAnswerStore` because the store is scoped to
//  a live onboarding session, while the two consumers that matter — the
//  commitment pact and (indirectly) the home greeting — run after that view
//  is gone. The UserDefaults key is the durable hand-off between them.
//
//  Skipping is a first-class answer. Nothing is written when the user skips,
//  and anything written on an earlier pass is removed, so "no name" is a
//  single condition everywhere downstream rather than a mix of nil, "" and
//  "User".
//

import Foundation

enum OnboardingNameKey {
    /// Key inside `OnboardingAnswerStore.answers`. The store mirrors it to
    /// UserDefaults as `onboarding_<key>`, which is `defaultsKey` below.
    static let answerKey = "name"

    /// Durable location, written by `OnboardingAnswerStore.setAnswer`.
    static let defaultsKey = "onboarding_name"

    /// Longest name we will store. The home greeting renders at 24pt and the
    /// pact headline at 30pt; past roughly this length both start wrapping
    /// into the layout below them. Enforced at the input rather than at each
    /// render site so what the user typed is what they later see.
    static let maxLength = 20

    /// Trim, collapse runs of whitespace, and cap length. Returns `nil` for
    /// anything that isn't a usable name, which is the single "treat this as
    /// skipped" signal for every caller.
    static func sanitized(_ raw: String?) -> String? {
        guard let raw else { return nil }
        let collapsed = raw
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        return String(collapsed.prefix(maxLength))
    }

    /// The name the user gave during onboarding, or `nil` if they skipped.
    ///
    /// Deliberately reads the onboarding answer and not
    /// `UserProfileStore.displayName`: the latter can hold a name that came
    /// from Sign in with Apple, and personalising the pact for someone who
    /// chose to skip the question would be the one behaviour the skip is
    /// supposed to buy them.
    static var current: String? {
        sanitized(UserDefaults.standard.string(forKey: defaultsKey))
    }
}
