//
//  OnboardingOptionTests.swift
//  WingmanTests
//
//  WP1 of the localization plan: an onboarding answer has an id (compared in
//  code), a canonical value (stored and sent, frozen English) and a label
//  (read by the user). These tests check the three stay separate, and that
//  what is stored does not depend on the label.
//

import XCTest
@testable import Wingman

@MainActor
final class OnboardingOptionTests: XCTestCase {

    private func step(_ key: String) -> OnboardingStep {
        extendedOnboardingSteps.first { $0.questionKey == key }!
    }

    private var questionSteps: [OnboardingStep] {
        extendedOnboardingSteps.filter { $0.choices != nil }
    }

    // MARK: - Catalog shape

    func testEveryQuestionIsBackedByItsOptionEnum() {
        XCTAssertEqual(step(MotivationOption.questionKey).choices, MotivationOption.options)
        XCTAssertEqual(step(AgeOption.questionKey).choices, AgeOption.options)
        XCTAssertEqual(step(LastApproachOption.questionKey).choices, LastApproachOption.options)
        XCTAssertEqual(step(ApproachFrequencyOption.questionKey).choices, ApproachFrequencyOption.options)
        XCTAssertEqual(step(BarrierOption.questionKey).choices, BarrierOption.options)
        XCTAssertEqual(step(GoalOption.questionKey).choices, GoalOption.options)
        XCTAssertEqual(questionSteps.count, 6, "A question was added without an option enum test")
    }

    func testIDsAreUniqueWithinAQuestionAndPlainASCII() {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789_")
        for step in questionSteps {
            let ids = (step.choices ?? []).map(\.id)
            XCTAssertEqual(Set(ids).count, ids.count, "Duplicate option id in \(step.id)")
            for id in ids {
                XCTAssertFalse(id.isEmpty)
                XCTAssertTrue(id.unicodeScalars.allSatisfy(allowed.contains), "\(id) is not a plain identifier")
            }
        }
    }

    func testCanonicalValuesAreUniqueWithinAQuestion() {
        for step in questionSteps {
            let values = step.options ?? []
            XCTAssertEqual(Set(values).count, values.count, "Duplicate stored value in \(step.id)")
        }
    }

    // MARK: - Label vs stored value

    func testCorrectedSpellingIsALabelOnly() {
        XCTAssertEqual(BarrierOption.fearOfRejection.label, "Fear of rejection or being embarrassed")
        XCTAssertEqual(BarrierOption.fearOfRejection.canonicalValue, "Fear of rejection or being embarrased")
    }

    func testLabelsMatchStoredValuesEverywhereElse() {
        // True while the app is English-only. When labels are localized this
        // is the test to delete; the ones below must keep passing.
        for step in questionSteps {
            for choice in step.choices ?? [] where choice.id != BarrierOption.fearOfRejection.rawValue || step.questionKey != BarrierOption.questionKey {
                XCTAssertEqual(choice.label, choice.canonicalValue)
            }
        }
    }

    // MARK: - Selection -> stored value

    func testSingleSelectStoresTheCanonicalValue() {
        let stored = OnboardingAnswerCoding.storedValue(
            forSelectedIDs: [ApproachFrequencyOption.usuallyGoForIt.rawValue],
            in: ApproachFrequencyOption.options
        )
        XCTAssertEqual(stored, "No, I usually go for it")
    }

    func testMultiSelectStoresCanonicalValuesInTapOrder() {
        let stored = OnboardingAnswerCoding.storedValue(
            forSelectedIDs: [BarrierOption.whatToSay.rawValue, BarrierOption.fearOfRejection.rawValue],
            in: BarrierOption.options
        )
        XCTAssertEqual(stored, "Not knowing what to say or how to start, Fear of rejection or being embarrased")
    }

    func testUnknownIDsAreDroppedAndNothingSelectedStoresNothing() {
        XCTAssertEqual(
            OnboardingAnswerCoding.storedValue(forSelectedIDs: ["nope", GoalOption.attraction.rawValue], in: GoalOption.options),
            "Creating attraction and romantic interest"
        )
        XCTAssertEqual(OnboardingAnswerCoding.storedValue(forSelectedIDs: [], in: GoalOption.options), "")
        XCTAssertEqual(OnboardingAnswerCoding.storedValue(forSelectedIDs: ["nope"], in: GoalOption.options), "")
    }

    /// The point of WP1: relabel every option (as a translation would) and the
    /// value that is stored and sent to PostHog / Supabase is byte-identical.
    func testStoredValueDoesNotDependOnLabels() {
        for step in questionSteps {
            let english = step.choices ?? []
            let relabelled = english.map {
                OnboardingOption(id: $0.id, canonicalValue: $0.canonicalValue, label: "ÜBERSETZT, " + String($0.label.reversed()))
            }
            // A multi-select question can have everything picked; a
            // single-select one stores exactly one answer at a time.
            let selections: [[String]] = step.isMultiSelect ? [english.map(\.id)] : english.map { [$0.id] }

            for ids in selections {
                let stored = OnboardingAnswerCoding.storedValue(forSelectedIDs: ids, in: relabelled)
                XCTAssertEqual(stored, OnboardingAnswerCoding.storedValue(forSelectedIDs: ids, in: english))
                XCTAssertFalse(stored.contains("ÜBERSETZT"), "A label leaked into the stored value")
                XCTAssertEqual(
                    OnboardingAnswerCoding.selectedIDs(fromStoredValue: stored, in: relabelled, isMultiSelect: step.isMultiSelect),
                    ids
                )
            }
        }
    }

    // MARK: - Stored value -> selection

    func testMultiSelectRoundTrip() {
        let ids = [GoalOption.other.rawValue, GoalOption.mindsetAndConfidence.rawValue, GoalOption.howToApproach.rawValue]
        let stored = OnboardingAnswerCoding.storedValue(forSelectedIDs: ids, in: GoalOption.options)
        XCTAssertEqual(stored, "Other, Better mindset & confidence, Learning how to approach")
        XCTAssertEqual(OnboardingAnswerCoding.selectedIDs(fromStoredValue: stored, in: GoalOption.options, isMultiSelect: true), ids)
    }

    func testSingleSelectValueContainingTheSeparatorIsRestoredWhole() {
        XCTAssertEqual(
            OnboardingAnswerCoding.selectedIDs(fromStoredValue: "No, I usually go for it", in: ApproachFrequencyOption.options, isMultiSelect: false),
            [ApproachFrequencyOption.usuallyGoForIt.rawValue]
        )
    }

    func testLegacyAndUnknownStoredValuesRestoreNothing() {
        XCTAssertEqual(OnboardingAnswerCoding.selectedIDs(fromStoredValue: "45+", in: AgeOption.options, isMultiSelect: false), [])
        XCTAssertEqual(OnboardingAnswerCoding.selectedIDs(fromStoredValue: "gibberish", in: BarrierOption.options, isMultiSelect: true), [])
        // A removed option inside a multi-select answer is dropped, the rest kept.
        XCTAssertEqual(
            OnboardingAnswerCoding.selectedIDs(fromStoredValue: "Removed option, Other", in: BarrierOption.options, isMultiSelect: true),
            [BarrierOption.other.rawValue]
        )
    }

    // MARK: - Stored value -> typed option

    func testStoredValueResolvesToItsCase() {
        for option in BarrierOption.allCases {
            XCTAssertEqual(BarrierOption(storedValue: option.canonicalValue), option)
        }
        for option in MotivationOption.allCases {
            XCTAssertEqual(MotivationOption(storedValue: option.canonicalValue), option)
        }
        for option in GoalOption.allCases {
            XCTAssertEqual(GoalOption(storedValue: option.canonicalValue), option)
        }
        for option in AgeOption.allCases {
            XCTAssertEqual(AgeOption(storedValue: option.canonicalValue), option)
        }
    }

    func testUnresolvableStoredValuesAreNil() {
        XCTAssertNil(BarrierOption(storedValue: nil))
        XCTAssertNil(BarrierOption(storedValue: ""))
        XCTAssertNil(AgeOption(storedValue: "45+"))
        // Labels and ids are not stored values.
        XCTAssertNil(BarrierOption(storedValue: "Fear of rejection or being embarrassed"))
        XCTAssertNil(BarrierOption(storedValue: BarrierOption.fearOfRejection.rawValue))
        // An answer to a different question does not resolve here.
        XCTAssertNil(GoalOption(storedValue: MotivationOption.freeze.canonicalValue))
    }

    func testFirstPick() {
        XCTAssertEqual(OnboardingAnswerCoding.firstPick(ofStoredValue: "Other, Learning how to approach"), "Other")
        XCTAssertEqual(OnboardingAnswerCoding.firstPick(ofStoredValue: "Keeping conversations going"), "Keeping conversations going")
        XCTAssertNil(OnboardingAnswerCoding.firstPick(ofStoredValue: nil))
    }
}
