//
//  NotificationCopyTests.swift
//  WingmanTests
//
//  WP5 of the localization plan, fifth slice: notification text.
//
//  The one-off reminders are scheduled days ahead, so their bodies are
//  handed to the system as keys and localized at delivery. The daily reading
//  reminder is rescheduled on every launch, so it is localized when
//  scheduled. Either way the English text must be exactly what it was.
//
//  (The reminder wording per answer is pinned in
//  PersonalisationCharacterizationTests.)
//

import XCTest
@testable import Wingman

@MainActor
final class NotificationCopyTests: XCTestCase {

    private let answerKeys = ["onboarding_motivation", "onboarding_barriers", "onboarding_goals"]
    private var savedAnswers: [String: String?] = [:]

    override func setUp() {
        super.setUp()
        for key in answerKeys {
            savedAnswers[key] = UserDefaults.standard.string(forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    override func tearDown() {
        for key in answerKeys {
            if let value = savedAnswers[key] ?? nil {
                UserDefaults.standard.set(value, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        super.tearDown()
    }

    // MARK: - Daily reading reminder

    func testDailyReadingText() {
        let text = NotificationManager.dailyReadingText(goalMinutes: 10)
        XCTAssertEqual(text.title, "Daily Reading Reminder")
        XCTAssertEqual(text.body, "Time for your daily reading! Your goal is 10 minutes today.")
        XCTAssertEqual(
            NotificationManager.dailyReadingText(goalMinutes: 30).body,
            "Time for your daily reading! Your goal is 30 minutes today."
        )
    }

    // MARK: - Marketing reminders

    func testTitleIsTheBrandName() {
        XCTAssertEqual(MarketingNotifications.brandTitle, "Wingman")
    }

    /// The key handed to the system is the English sentence itself, so an
    /// untranslated reminder is delivered in English, never as an opaque key.
    func testReminderKeysAreTheEnglishSentences() {
        XCTAssertEqual(
            MarketingNotifications.motivationResource("Done with dating apps").key,
            "When did you last meet someone without a screen in between?"
        )
        XCTAssertEqual(
            MarketingNotifications.barrierResource("Fear of rejection or being embarrased").key,
            "What\u{2019}s the worst a polite \u{201C}no\u{201D} could actually cost you?"
        )
        XCTAssertEqual(
            MarketingNotifications.goalResource("Keeping conversations going").key,
            "What\u{2019}s one question you could ask that isn\u{2019}t small talk?"
        )
        XCTAssertEqual(
            MarketingNotifications.goalResource(nil).key,
            "Who would you talk to this week if nerves weren\u{2019}t a factor?"
        )
    }

    /// Each line function and its resource are the same sentence.
    func testLinesMatchTheirResources() {
        for option in MotivationOption.allCases {
            let stored = option.canonicalValue
            XCTAssertEqual(MarketingNotifications.motivationLine(stored), MarketingNotifications.motivationResource(stored).key)
        }
        for option in BarrierOption.allCases {
            let stored = option.canonicalValue
            XCTAssertEqual(MarketingNotifications.barrierLine(stored), MarketingNotifications.barrierResource(stored).key)
        }
        for option in GoalOption.allCases {
            let stored = option.canonicalValue
            XCTAssertEqual(MarketingNotifications.goalLine(stored), MarketingNotifications.goalResource(stored).key)
        }
    }

    /// The keys are passed to the system as format strings with no
    /// arguments; a "%" in one would be read as a placeholder.
    func testReminderKeysContainNoFormatCharacters() {
        let keys =
            (MotivationOption.allCases.map { MarketingNotifications.motivationResource($0.canonicalValue).key })
            + (BarrierOption.allCases.map { MarketingNotifications.barrierResource($0.canonicalValue).key })
            + (GoalOption.allCases.map { MarketingNotifications.goalResource($0.canonicalValue).key })
        XCTAssertEqual(keys.count, 16)
        for key in keys {
            XCTAssertFalse(key.contains("%"), key)
            XCTAssertFalse(key.isEmpty)
        }
    }

    func testDeliveryLocalizedBodyReadsAsEnglishToday() {
        let resource = MarketingNotifications.barrierResource("Fear of social consequences")
        XCTAssertEqual(
            MarketingNotifications.deliveryLocalized(resource),
            "Would anyone around you really remember you saying hi?"
        )
    }

    func testBodiesForAUserWithAnswers() {
        UserDefaults.standard.set("Tired of being on my own, Other", forKey: "onboarding_motivation")
        UserDefaults.standard.set("Worrying about coming across wrong", forKey: "onboarding_barriers")
        UserDefaults.standard.set("Creating attraction and romantic interest, Learning how to approach", forKey: "onboarding_goals")

        let bodies = MarketingNotifications.personalisedBodies()
        XCTAssertEqual(Set(bodies.keys), ["day1", "day3", "day7"])
        XCTAssertEqual(bodies["day1"]?.key, "Who did you notice today that you didn\u{2019}t talk to?")
        XCTAssertEqual(bodies["day3"]?.key, "What if a little nervousness just reads as genuine?")
        XCTAssertEqual(bodies["day7"]?.key, "When did a conversation last feel like more than small talk?")
    }

    func testBodiesForAUserWithNoAnswers() {
        let bodies = MarketingNotifications.personalisedBodies()
        XCTAssertEqual(bodies["day1"]?.key, "When did you last start a conversation with a stranger?")
        XCTAssertEqual(bodies["day3"]?.key, "What\u{2019}s the one thing that stops you from saying hi?")
        XCTAssertEqual(bodies["day7"]?.key, "Who would you talk to this week if nerves weren\u{2019}t a factor?")
    }
}
