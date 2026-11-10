//
//  PersonalisationCharacterizationTests.swift
//  WingmanTests
//
//  Records what each stored onboarding answer selects today: the paywall
//  ticks, the day 1/3/7 reminder lines and the statistic interstitials.
//  Written before the localization refactor (WP1) so that moving these
//  switches from English text to option IDs can be shown to change nothing,
//  including for legacy and unrecognised stored values.
//

import XCTest
@testable import Wingman

@MainActor
final class PersonalisationCharacterizationTests: XCTestCase {

    // MARK: - Paywall ticks

    func testPaywallBarrierLines() {
        XCTAssertEqual(PaywallCopy.barrierLine("Fear of rejection or being embarrased"), "Stop letting fear of rejection win")
        XCTAssertEqual(PaywallCopy.barrierLine("Fear of social consequences"), "Stop caring what others think")
        XCTAssertEqual(PaywallCopy.barrierLine("Not knowing what to say or how to start"), "Know exactly how to start talking")
        XCTAssertEqual(PaywallCopy.barrierLine("Worrying about coming across wrong"), "Come across natural, not nervous")
    }

    func testPaywallBarrierFallbacks() {
        let fallback = "Stop talking yourself out of it"
        XCTAssertEqual(PaywallCopy.barrierLine("Other"), fallback)
        XCTAssertEqual(PaywallCopy.barrierLine(nil), fallback)
        XCTAssertEqual(PaywallCopy.barrierLine("something from an older build"), fallback)
        // The corrected spelling is a display label only; it was never stored.
        XCTAssertEqual(PaywallCopy.barrierLine("Fear of rejection or being embarrassed"), fallback)
    }

    func testPaywallGoalLines() {
        XCTAssertEqual(PaywallCopy.goalLine("Better mindset & confidence"), "Feel confident, not anxious")
        XCTAssertEqual(PaywallCopy.goalLine("Learning how to approach"), "Walk up to her without hesitating")
        XCTAssertEqual(PaywallCopy.goalLine("Keeping conversations going"), "Keep it flowing, no awkward silences")
        XCTAssertEqual(PaywallCopy.goalLine("Creating attraction and romantic interest"), "Turn small talk into real chemistry")
    }

    func testPaywallGoalFallbacks() {
        let fallback = "Go first without overthinking it"
        XCTAssertEqual(PaywallCopy.goalLine("Other"), fallback)
        XCTAssertEqual(PaywallCopy.goalLine(nil), fallback)
        XCTAssertEqual(PaywallCopy.goalLine("something from an older build"), fallback)
    }

    // MARK: - Reminder notifications

    func testReminderMotivationLines() {
        XCTAssertEqual(MarketingNotifications.motivationLine("Back on the market after a breakup or divorce"),
                       "What would your first conversation back out there sound like?")
        XCTAssertEqual(MarketingNotifications.motivationLine("I freeze up around women I find attractive"),
                       "What happens in the second before you freeze?")
        XCTAssertEqual(MarketingNotifications.motivationLine("Done with dating apps"),
                       "When did you last meet someone without a screen in between?")
        XCTAssertEqual(MarketingNotifications.motivationLine("Tired of being on my own"),
                       "Who did you notice today that you didn\u{2019}t talk to?")
        XCTAssertEqual(MarketingNotifications.motivationLine("Want more confidence in general"),
                       "Where in your day could you say one more hello?")

        let fallback = "When did you last start a conversation with a stranger?"
        XCTAssertEqual(MarketingNotifications.motivationLine("Other"), fallback)
        XCTAssertEqual(MarketingNotifications.motivationLine(nil), fallback)
    }

    func testReminderBarrierLines() {
        XCTAssertEqual(MarketingNotifications.barrierLine("Fear of rejection or being embarrased"),
                       "What\u{2019}s the worst a polite \u{201C}no\u{201D} could actually cost you?")
        XCTAssertEqual(MarketingNotifications.barrierLine("Fear of social consequences"),
                       "Would anyone around you really remember you saying hi?")
        XCTAssertEqual(MarketingNotifications.barrierLine("Not knowing what to say or how to start"),
                       "What if your opener didn\u{2019}t need to be clever?")
        XCTAssertEqual(MarketingNotifications.barrierLine("Worrying about coming across wrong"),
                       "What if a little nervousness just reads as genuine?")

        let fallback = "What\u{2019}s the one thing that stops you from saying hi?"
        XCTAssertEqual(MarketingNotifications.barrierLine("Other"), fallback)
        XCTAssertEqual(MarketingNotifications.barrierLine(nil), fallback)
    }

    func testReminderGoalLines() {
        XCTAssertEqual(MarketingNotifications.goalLine("Better mindset & confidence"),
                       "What would feeling sure of yourself change this week?")
        XCTAssertEqual(MarketingNotifications.goalLine("Keeping conversations going"),
                       "What\u{2019}s one question you could ask that isn\u{2019}t small talk?")
        XCTAssertEqual(MarketingNotifications.goalLine("Creating attraction and romantic interest"),
                       "When did a conversation last feel like more than small talk?")

        // "Learning how to approach" deliberately shares the default line.
        let fallback = "Who would you talk to this week if nerves weren\u{2019}t a factor?"
        XCTAssertEqual(MarketingNotifications.goalLine("Learning how to approach"), fallback)
        XCTAssertEqual(MarketingNotifications.goalLine("Other"), fallback)
        XCTAssertEqual(MarketingNotifications.goalLine(nil), fallback)
    }

    // MARK: - Statistic interstitials

    func testStatisticAfterLastApproachDependsOnAge() {
        func fact(_ age: String) -> String? {
            StatisticContent.for(questionKey: "last_approach", ageGroup: age)?.fact
        }
        func heading(_ age: String) -> String? {
            StatisticContent.for(questionKey: "last_approach", ageGroup: age)?.heading
        }

        XCTAssertEqual(fact("18-24"), "45% of men aged 18-24 have never approached a woman")
        XCTAssertEqual(heading("18-24"), "Almost half of men your age have never approached a woman")

        for age in ["25-34", "35-44"] {
            XCTAssertEqual(fact(age), "48% of men aged 26-40 haven't approached in the past year")
            XCTAssertEqual(heading(age), "Almost half of men your age haven't approached in the past year")
        }

        // Older brackets, the legacy "45+" and a missing answer all get the
        // figure without the "your age" claim, and never nil.
        for age in ["45-54", "55+", "45+", ""] {
            XCTAssertEqual(fact(age), "48% of men aged 26-40 haven't approached in the past year")
            XCTAssertEqual(heading(age), "Almost half of men haven't approached in the past year")
        }
    }

    func testStatisticsForOtherQuestions() {
        func stat(_ key: String) -> StatisticContent? {
            StatisticContent.for(questionKey: key, ageGroup: "25-34")
        }
        XCTAssertEqual(stat("approach_frequency")?.fact, "77% of women aged between 18 and 30 want to be approached more")
        XCTAssertEqual(stat("approach_frequency")?.imageName, "stat_frequency")
        XCTAssertEqual(stat("barriers")?.fact, "63% of single men regret not approaching women when they were younger")
        XCTAssertEqual(stat("barriers")?.imageName, "stat_regret")
        XCTAssertEqual(stat("goals")?.fact, "58% of men who consistently approach get a number, date, or relationship")
        XCTAssertEqual(stat("goals")?.imageName, "stat_success")

        XCTAssertNil(stat("motivation"))
        XCTAssertNil(stat("age"))
        XCTAssertNil(stat("growth_projection"))
    }
}
