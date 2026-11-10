//
//  OnboardingCanonicalValuesTests.swift
//  WingmanTests
//
//  Pins the onboarding answer values that are stored in UserDefaults, sent to
//  PostHog as `onboarding_<key>` person properties and written to Supabase
//  user_metadata. Localization must never change them — see
//  docs/localization-implementation-plan.md (rules R1/R2) and
//  docs/localization-analytics-baseline.md.
//
//  If one of these fails, a stored/analytics value changed. That is a data
//  break, not a copy edit: do not "fix" the test by updating the string.
//

import XCTest
@testable import Wingman

@MainActor
final class OnboardingCanonicalValuesTests: XCTestCase {

    private func step(_ key: String) -> OnboardingStep? {
        extendedOnboardingSteps.first { $0.questionKey == key }
    }

    func testStepKeysAndOrder() {
        XCTAssertEqual(
            extendedOnboardingSteps.map(\.questionKey),
            ["motivation", "age", "last_approach", "approach_frequency",
             "barriers", "goals", "growth_projection", nil, "social_proof"]
        )
    }

    func testMotivationValues() {
        XCTAssertEqual(step("motivation")?.options, [
            "Back on the market after a breakup or divorce",
            "I freeze up around women I find attractive",
            "Done with dating apps",
            "Tired of being on my own",
            "Want more confidence in general",
            "Other"
        ])
    }

    func testAgeValues() {
        XCTAssertEqual(step("age")?.options, ["18-24", "25-34", "35-44", "45-54", "55+"])
    }

    func testLastApproachValues() {
        XCTAssertEqual(step("last_approach")?.options, [
            "Within the past week",
            "Within the past month",
            "A few months ago",
            "More than a year ago",
            "Never approached before"
        ])
    }

    func testApproachFrequencyValues() {
        XCTAssertEqual(step("approach_frequency")?.options, [
            "Every time",
            "Most times",
            "Sometimes",
            "Rarely",
            "No, I usually go for it"
        ])
    }

    func testBarrierValues() {
        // "embarrased" is misspelled on purpose: it is the stored value.
        XCTAssertEqual(step("barriers")?.options, [
            "Fear of rejection or being embarrased",
            "Fear of social consequences",
            "Not knowing what to say or how to start",
            "Worrying about coming across wrong",
            "Other"
        ])
    }

    func testGoalValues() {
        XCTAssertEqual(step("goals")?.options, [
            "Better mindset & confidence",
            "Learning how to approach",
            "Keeping conversations going",
            "Creating attraction and romantic interest",
            "Other"
        ])
    }

    func testMultiSelectKeys() {
        let multi = extendedOnboardingSteps.filter(\.isMultiSelect).compactMap(\.questionKey)
        XCTAssertEqual(multi, ["motivation", "barriers", "goals"])
    }

    /// Multi-select answers are stored ", "-joined and split on ", " again, so
    /// no multi-select stored value may contain that separator.
    func testMultiSelectValuesContainNoSeparator() {
        for step in extendedOnboardingSteps where step.isMultiSelect {
            for option in step.options ?? [] {
                XCTAssertFalse(option.contains(", "), "\(option) contains the multi-select separator")
            }
        }
    }
}
