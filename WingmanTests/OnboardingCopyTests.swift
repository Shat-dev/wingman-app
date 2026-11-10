//
//  OnboardingCopyTests.swift
//  WingmanTests
//
//  WP5 of the localization plan, third slice: the onboarding and commitment
//  copy held in models and constants became localizable
//  (`String(localized:)`). These tests pin the English wording character for
//  character, so making a string translatable can be shown to have changed
//  nothing an English user reads — including the ones with "%", curly quotes
//  and an interpolated name, which are the easy ones to get subtly wrong.
//
//  (The statistic screens are pinned in PersonalisationCharacterizationTests.)
//

import XCTest
@testable import Wingman

@MainActor
final class OnboardingCopyTests: XCTestCase {

    private func step(_ key: String?) -> OnboardingStep? {
        extendedOnboardingSteps.first { $0.questionKey == key }
    }

    func testQuestionTitles() {
        XCTAssertEqual(step("motivation")?.title, "What brought you to Wingman?")
        XCTAssertEqual(step("age")?.title, "How old are you?")
        XCTAssertEqual(step("last_approach")?.title, "When was the last time you spoke to a woman in public?")
        XCTAssertEqual(step("approach_frequency")?.title, "Do you often want to talk to women but don\u{2019}t?")
        XCTAssertEqual(step("barriers")?.title, "What usually stops you from doing so?")
        XCTAssertEqual(step("goals")?.title, "What are you mainly hoping to improve?")
    }

    func testLoadingStepCopy() {
        let loading = step(nil)
        XCTAssertEqual(loading?.type, .loading)
        XCTAssertEqual(loading?.title, "Optimizing your experience")
        XCTAssertEqual(loading?.subtitle, "Confidence is a skill. Skills are built.")
    }

    func testGrowthProjectionCopy() {
        let content = GrowthProjectionContent.default
        XCTAssertEqual(content.headline, "Build the confidence to take action when it matters")
        XCTAssertEqual(content.bullets.map(\.emphasis), ["3x", nil, nil])
        XCTAssertEqual(content.bullets.map(\.text), [
            "faster progress than watching generic advice videos",
            "Bite-sized lessons you can do on your commute or lunch break",
            "Science-based techniques that actually stick"
        ])
        XCTAssertEqual(content.positiveLabel, "Using Wingman every day")
        XCTAssertEqual(content.negativeLabel, "Doing nothing")
        XCTAssertNil(content.footnote)
    }

    func testSocialProofCopy() {
        let content = SocialProofContent.default
        XCTAssertEqual(content.headline, "Join the men taking action")
        XCTAssertEqual(content.subtitle, "You're not the only one who's been stuck here.")
        XCTAssertEqual(content.footnote, "Things Wingman users have said")
        XCTAssertEqual(content.testimonials, [
            "I used to freeze up walking past a girl. After 3 weeks I had my first real conversation with a stranger. That was the win.",
            "I've read every book on this \u{2014} none of them made me actually do anything. The daily structure changed that.",
            "No corny lines. Just calm, practical stuff about being present. My social anxiety is half what it was.",
            "I stopped dreading social situations entirely. That's worth more than any date."
        ])
    }

    func testCommitmentPactCopy() {
        XCTAssertEqual(CommitmentPactCopy.pact.headline, "I am becoming a guy who takes action.")
        XCTAssertEqual(
            CommitmentPactCopy.pact.body,
            "To achieve what I want, I must grow. I won\u{2019}t let fear make the decision for me. I\u{2019}ll take my chance, and learn from what happens."
        )
        XCTAssertEqual(CommitmentPactCopy.holdInstruction, "Tap and hold to commit.")
        XCTAssertEqual(CommitmentPactCopy.committed, "Committed.")
    }

    func testCommitmentHeadlineWithAndWithoutAName() {
        XCTAssertEqual(CommitmentPactCopy.headline(for: nil), "I am becoming a guy who takes action.")
        XCTAssertEqual(CommitmentPactCopy.headline(for: ""), "I am becoming a guy who takes action.")
        XCTAssertEqual(CommitmentPactCopy.headline(for: "Sam"), "I, Sam, am becoming a guy who takes action.")
        // A name containing format characters must come through literally.
        XCTAssertEqual(CommitmentPactCopy.headline(for: "100% Dan"), "I, 100% Dan, am becoming a guy who takes action.")
        XCTAssertEqual(CommitmentPactCopy.headline(for: "%@"), "I, %@, am becoming a guy who takes action.")
    }

    /// The on-screen headline and the analytics value start out as the same
    /// sentence but are separate constants; only the first is copy.
    func testAnalyticsHeadlineIsIndependentOfTheDisplayedOne() {
        XCTAssertEqual(CommitmentPactCopy.analyticsHeadline, "I am becoming a guy who takes action.")
        XCTAssertEqual(CommitmentPactCopy.pact.headline, CommitmentPactCopy.analyticsHeadline)
    }

    /// Statistics carry a literal "%", which a format-string lookup could
    /// double or swallow.
    func testPercentSignsSurviveLocalization() {
        let fact = StatisticContent.for(questionKey: "approach_frequency", ageGroup: "25-34")?.fact
        XCTAssertEqual(fact, "77% of women aged between 18 and 30 want to be approached more")
        XCTAssertEqual(fact?.filter { $0 == "%" }.count, 1)
    }
}
