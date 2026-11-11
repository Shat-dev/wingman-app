//
//  OnboardingSweepTests.swift
//  WingmanUITests
//
//  Walks a fresh install from the landing screen through onboarding, the
//  paywall, the first-run walkthrough and the four tabs, with fixed answers,
//  attaching a screenshot of every screen. The attachments are the visual
//  baseline for the localization work: run it before and after a change and
//  compare the images.
//
//  Two runs, one test method each. Run ONE method per run
//  (`-only-testing:WingmanUITests/OnboardingSweepTests/<method>`):
//
//    testOnboardingToPaywall
//        English, as shipped. Screens 01-17 are compared against
//        docs/localization-baseline.
//
//    testOnboardingInDoubleLengthPseudoLanguage
//        The same walk with every localized string doubled
//        (`-NSDoubleLocalizedStrings YES`, the system's pseudo-language) and
//        the layouts built for translated apps switched on
//        (`-l10nForceTranslatedLayout YES`). Nothing is compared; the
//        screenshots are read for clipped, cut or overlapping text. No
//        language has to exist for this.
//
//  Needs a clean install: uninstall the app and reset the simulator keychain
//  first, otherwise a stored guest session skips onboarding.
//
//  Side effects of a run: tapping "Get started" creates an anonymous Supabase
//  user, and events are sent to PostHog tagged `environment = dev` (Debug).
//  Each method is one such user. Run it on a throwaway simulator and not in
//  a loop.
//
//    testOnboardingInGerman
//        The same walk with the app launched in German (`-AppleLanguages (de)`).
//        Nothing is compared; the screenshots are read for German layout
//        problems (Release B, G7).
//
//    testOnboardingAndContentInGerman
//        The German walk, then a relaunch with the Debug-only
//        `-forcePremium YES` and a walk through the first lesson and its
//        quiz, today's Daily Practice and the "Bar Window" scenario, to see
//        the German lesson overlays and database rows on screen. Also
//        records those completions for its guest user in production.
//
//  Elements are found by the start of their visible text because the app has
//  no accessibility identifiers yet (the start, so that a doubled string
//  still matches). The walk names them in English; in the German run `t()`
//  turns each into its German text from localization/de/catalogs.de.json.
//
//  Everything up to the paywall is asserted. What follows the paywall is
//  walked as far as it goes and never fails the run: those screens depend on
//  the network and on feature switches, and a missing one should not cost
//  the screenshots already taken.
//

import XCTest

final class OnboardingSweepTests: XCTestCase {

    private var app: XCUIApplication!
    private var shot = 0

    /// English text -> German, for the German run only. Empty otherwise.
    private var german: [String: String] = [:]

    /// The start of a longer string the walk looks for by its beginning.
    /// The catalog has only the whole sentence, so these are listed by hand.
    private static let germanPrefixes: [String: String] = [
        "Welcome to Wingman": "Willkommen bei Wingman",
        "Courses. Mindset": "Kurse. Mindset",
        "And this is where you practise": "Und hier übst du",
        "Last one. This one is you": "Der Letzte. Das bist du",
        "Good luck": "Viel Glück",
        "Commit": "Verpflichten"
    ]

    private static func loadGerman() -> [String: String] {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("localization/de/catalogs.de.json")
        guard let data = try? Data(contentsOf: url),
              let catalogs = try? JSONSerialization.jsonObject(with: data) as? [String: [String: Any]] else { return [:] }
        var table: [String: String] = [:]
        for strings in catalogs.values {
            for (english, value) in strings {
                if let text = value as? String { table[english] = text }
            }
        }
        return table.merging(germanPrefixes) { _, prefix in prefix }
    }

    /// The text the running app shows for `english`.
    private func t(_ english: String) -> String {
        german.isEmpty ? english : (german[english] ?? english)
    }

    /// Set to true, for one run, to also photograph the paywall with the
    /// monthly plan selected. See the note where it is used before doing so.
    private static let selectsPlansOnThePaywall = false

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    func testOnboardingToPaywall() {
        app.launch()
        walkFromLandingThroughTheApp()
    }

    func testOnboardingInGerman() {
        german = Self.loadGerman()
        XCTAssertFalse(german.isEmpty, "Could not read localization/de/catalogs.de.json")
        app.launchArguments += ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launch()
        walkFromLandingThroughTheApp()
    }

    /// The German walk, then the content a subscriber sees: the first lesson
    /// and its quiz, today's Daily Practice, and the "Bar Window" scenario.
    ///
    /// Nothing is free for a guest who closed the paywall, so after the
    /// onboarding walk the app is relaunched with the Debug-only
    /// `-forcePremium YES`, which makes this simulator's app treat the user as
    /// subscribed. Nothing is bought and RevenueCat is not touched. Not passed
    /// on the first launch: a subscriber never sees the onboarding paywall.
    ///
    /// Side effects, beyond the guest user every run creates: the lesson, the
    /// Daily Practice set and the scenario are recorded as completed for that
    /// guest in production (progress, streak, XP rows), as any user's would be.
    func testOnboardingAndContentInGerman() {
        german = Self.loadGerman()
        XCTAssertFalse(german.isEmpty, "Could not read localization/de/catalogs.de.json")
        let language = ["-AppleLanguages", "(de)", "-AppleLocale", "de_DE"]
        app.launchArguments += language
        app.launch()
        walkFromLandingThroughTheApp()

        app.terminate()
        app = XCUIApplication()
        app.launchArguments = language + [
            "-forcePremium", "YES",
            "-lessonQuizEnabled", "YES",
            "-reviewPromptEnabled", "NO"
        ]
        app.launch()

        // A guest who counts as subscribed is first offered an account.
        let notNow = button("Not now")
        if notNow.waitForExistence(timeout: 15) {
            settle(1.0)
            snap("unlocked-account-offer")
            notNow.tap()
        }

        var problems: [String] = []
        if let problem = walkLessonAndItsQuiz() { problems.append(problem) }
        returnToTabs()
        if let problem = walkDailyPractice() { problems.append(problem) }
        returnToTabs()
        if let problem = walkScenario() { problems.append(problem) }
        XCTAssertTrue(problems.isEmpty, problems.joined(separator: "; "))
    }

    func testOnboardingInDoubleLengthPseudoLanguage() {
        app.launchArguments += [
            "-NSDoubleLocalizedStrings", "YES",
            "-l10nForceTranslatedLayout", "YES"
        ]
        app.launch()
        walkFromLandingThroughTheApp()
    }

    // MARK: - The walk

    private func walkFromLandingThroughTheApp() {
        // Landing
        let getStarted = button("Get started")
        XCTAssertTrue(getStarted.waitForExistence(timeout: 20), "Landing screen did not appear")
        snap("landing")
        getStarted.tap()

        // 1. Motivation (multi-select)
        answer("Want more confidence in general", name: "q-motivation")

        // 2. Age
        answer("25-34", name: "q-age")

        // 3. Last approach, then its statistic
        answer("Within the past month", name: "q-last-approach")
        continuePastStatistic(name: "stat-last-approach")

        // 4. Frequency, then its statistic
        answer("Sometimes", name: "q-approach-frequency")
        continuePastStatistic(name: "stat-approach-frequency")

        // 5. Barriers (multi-select), then its statistic
        answer("Not knowing what to say or how to start", name: "q-barriers")
        continuePastStatistic(name: "stat-barriers")

        // 6. Goals (multi-select), then its statistic
        answer("Learning how to approach", name: "q-goals")
        continuePastStatistic(name: "stat-goals")

        // 7. Growth projection
        let projectionContinue = button("Continue")
        XCTAssertTrue(projectionContinue.waitForExistence(timeout: 10), "Growth projection did not appear")
        settle(2.5) // chart animation
        snap("growth-projection")
        projectionContinue.tap()

        // 8. Loading screen, with the system notification prompt on top
        settle(1.0)
        snap("loading")
        dismissNotificationPromptIfShown()

        // 9. Social proof
        let socialContinue = button("Continue")
        XCTAssertTrue(socialContinue.waitForExistence(timeout: 20), "Social proof did not appear")
        settle(1.0)
        snap("social-proof")
        socialContinue.tap()

        // 10. Commitment pact (press and hold). Skipped by the app if the
        //     pact is switched off, so its absence is not a failure.
        let commit = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", t("Commit"))).firstMatch
        if commit.waitForExistence(timeout: 8) {
            settle(0.8)
            snap("commitment-pact")
            commit.press(forDuration: 2.5)
        }

        // 11. Paywall. The close button appears a few seconds after the
        //     paywall does. A Debug build cannot load prices, so this
        //     captures the "Can't load pricing" state; the priced paywall
        //     needs a Release build.
        let close = button("Close paywall")
        XCTAssertTrue(close.waitForExistence(timeout: 25), "Paywall did not appear")

        // In a build that loads products the plan rows arrive a moment
        // after the paywall; give them a few seconds before the picture.
        let monthlyRow = buttonContaining("Monthly Plan")
        let hasPrices = monthlyRow.waitForExistence(timeout: 8)
        settle(2.0)
        snap("paywall")

        // With prices: the same paywall with the monthly plan selected (the
        // trial badge moves to it), then back to yearly. Named 17b so the
        // numbering of the screens after it is the same in every build.
        //
        // OFF unless `selectsPlansOnThePaywall` is set. Tapping a plan sends
        // `paywall_plan_selected`, and prices only load in a Release build,
        // whose events are tagged production: two taps here are two
        // selections in the plan-mix numbers. The run of 2026-11-10 did this
        // once before the switch existed (filter: `$is_emulator = true`).
        if Self.selectsPlansOnThePaywall, hasPrices, monthlyRow.isHittable {
            monthlyRow.tap()
            settle(1.0)
            snapExtra("17b-paywall-monthly-selected")
            let yearlyRow = buttonContaining("Yearly Plan")
            if yearlyRow.exists, yearlyRow.isHittable {
                yearlyRow.tap()
                settle(0.6)
            }
        }

        walkPastThePaywall(close: close)
    }

    /// Paywall closed -> one-time offer (if it can be shown) -> first-run
    /// walkthrough -> the four tabs. Best effort: see the file header.
    private func walkPastThePaywall(close: XCUIElement) {
        close.tap()

        // 12. One-time offer. It closes itself when it cannot be honoured,
        //     which is always the case in a Debug build (no products), so
        //     this is normally skipped.
        //     Its close button appears three seconds after the offer does.
        let closeOffer = button("Close offer")
        if closeOffer.waitForExistence(timeout: 15) {
            settle(1.0)
            snapExtra("17c-one-time-offer")
            closeOffer.tap()
        }

        // 13. Walkthrough: five cards, each on top of a dimmed tab. A tap
        //     anywhere moves on.
        let cards: [(text: String, name: String)] = [
            ("Welcome to Wingman", "walkthrough-home"),
            ("Courses. Mindset", "walkthrough-courses"),
            ("And this is where you practise", "walkthrough-scenarios"),
            ("Last one. This one is you", "walkthrough-profile"),
            ("Good luck", "walkthrough-sign-off")
        ]
        for (index, card) in cards.enumerated() {
            let shown = anything(containing: card.text)
            guard shown.waitForExistence(timeout: index == 0 ? 20 : 8) else {
                snap("stopped-before-\(card.name)")
                return
            }
            settle(1.2)
            snap(card.name)
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.12)).tap()
        }

        // 14. The four tabs, as a new user who closed the paywall sees them.
        settle(2.5)
        for (tab, name) in [("Home", "tab-home"), ("Courses", "tab-courses"), ("Scenarios", "tab-scenarios"), ("Profile", "tab-profile")] {
            let tabButton = button(tab)
            guard tabButton.waitForExistence(timeout: 8), tabButton.isHittable else {
                snap("stopped-before-\(name)")
                return
            }
            tabButton.tap()
            settle(2.0)
            snap(name)
        }
    }

    // MARK: - Content (German run, unlocked)
    //
    // Best effort like the walk past the paywall: each path returns a
    // description of where it stopped, or nil, and the test fails at the end
    // so the screenshots of the other paths are still taken.

    /// Courses -> "Beliefs & Reframes" -> "You are not your thoughts", page by
    /// page, then the lesson quiz and the completion screen.
    private func walkLessonAndItsQuiz() -> String? {
        let courses = tabButton("Courses")
        guard courses.waitForExistence(timeout: 20) else { return "lesson: no Courses tab" }
        courses.tap()
        settle(2.0)
        snap("content-courses")

        let course = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", t("Beliefs & Reframes"))).firstMatch
        guard course.waitForExistence(timeout: 10) else { snap("stopped-before-course"); return "lesson: course card not found" }
        course.tap()
        settle(1.5)
        snap("content-course-detail")

        // Lesson titles come from the bundled German overlay, not the catalog.
        let lesson = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Du bist nicht deine Gedanken")).firstMatch
        guard lesson.waitForExistence(timeout: 10) else { snap("stopped-before-lesson"); return "lesson: lesson card not found" }
        lesson.tap()
        settle(1.5)
        snap("lesson-intro")

        // Pages advance by a tap on the right half: one paragraph per tap.
        let checkAnswer = button("Check Answer")
        let complete = staticText("Lesson complete.")
        for page in 1...30 {
            if checkAnswer.exists || complete.exists { break }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)).tap()
            settle(0.9)
            if checkAnswer.exists || complete.exists { break }
            snap(String(format: "lesson-page-%02d", page))
        }
        return answerQuiz(name: "lesson-quiz", completion: "Lesson complete.", firstWait: 10)
    }

    /// Home -> Daily Practice "Start" -> five questions -> completion.
    private func walkDailyPractice() -> String? {
        let home = tabButton("Home")
        guard home.waitForExistence(timeout: 10) else { return "daily practice: no Home tab" }
        home.tap()
        settle(2.0)
        snap("content-home")

        // "Home" and "Start" are both "Start" in German: the Daily Practice
        // button is the upper one, the tab the lowest.
        let starts = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", t("Start"))).allElementsBoundByIndex
            .filter { $0.isHittable }
            .sorted { $0.frame.minY < $1.frame.minY }
        guard starts.count >= 2 else {
            snap("stopped-before-daily-practice")
            return "daily practice: Start button not found (already done today, or offline)"
        }
        starts[0].tap()
        settle(1.0)
        snap("daily-practice-loading")
        return answerQuiz(name: "daily-practice", completion: "Daily practice complete.", firstWait: 25)
    }

    /// Scenarios -> "Bar Window" -> played to the end. Where a choice leads to
    /// "Tap to retry", the next visit to that choice takes the next option.
    private func walkScenario() -> String? {
        let scenarios = tabButton("Scenarios")
        guard scenarios.waitForExistence(timeout: 10) else { return "scenario: no Scenarios tab" }
        scenarios.tap()
        settle(3.0)
        snap("content-scenarios")

        let card = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Die Bar")).firstMatch
        guard card.waitForExistence(timeout: 15) else { snap("stopped-before-scenario"); return "scenario: \"Die Bar\" card not found" }
        card.tap()
        settle(1.5)
        snap("scenario-intro")

        let choose = staticText("Choose an option to continue")
        let complete = staticText("Scenario complete.")
        var tried: [String: Int] = [:]
        var shots = 0
        for _ in 1...80 {
            if complete.exists {
                settle(1.5)
                snap("scenario-complete")
                let next = button("Continue")
                if next.exists { next.tap() }
                return nil
            }
            if choose.exists {
                let options = wideButtons(excluding: [])
                guard !options.isEmpty else { snap("stopped-at-scenario-options"); return "scenario: options not found" }
                let key = options.map(\.label).joined(separator: "|")
                let index = tried[key, default: 0] % options.count
                tried[key, default: 0] += 1
                if shots < 60 { shots += 1; snap("scenario-choice") }
                options[index].tap()
                settle(1.6)
            } else {
                if shots < 60 { shots += 1; snap("scenario-screen") }
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)).tap()
                settle(1.0)
            }
        }
        snap("stopped-in-scenario")
        return "scenario: not finished after 80 steps"
    }

    /// Answers whatever quiz is on screen: the first option, "Check Answer",
    /// "Next", until the completion screen, whose "Continue" is tapped.
    private func answerQuiz(name: String, completion: String, firstWait: TimeInterval) -> String? {
        let checkAnswer = button("Check Answer")
        let complete = staticText(completion)
        for number in 1...12 {
            let deadline = Date().addingTimeInterval(number == 1 ? firstWait : 10)
            while !checkAnswer.exists && !complete.exists && Date() < deadline { settle(0.5) }
            if complete.exists {
                settle(2.0) // XP and streak animations
                snap("\(name)-complete")
                let next = button("Continue")
                guard next.waitForExistence(timeout: 5) else { return "\(name): no Continue on the completion screen" }
                next.tap()
                settle(1.5)
                return nil
            }
            guard checkAnswer.exists else { snap("stopped-in-\(name)"); return "\(name): question \(number) did not appear" }
            settle(0.8)
            snap("\(name)-q\(number)")
            let options = wideButtons(excluding: [t("Check Answer"), t("Next")])
            guard let first = options.first else { return "\(name): no options on question \(number)" }
            first.tap()
            settle(0.5)
            checkAnswer.tap()
            settle(1.2)
            snap("\(name)-q\(number)-checked")
            let next = button("Next")
            guard next.waitForExistence(timeout: 5) else { return "\(name): no Next after question \(number)" }
            next.tap()
            settle(1.0)
        }
        return "\(name): no completion screen after 12 questions"
    }

    /// Back to a screen with the tab bar: edge swipes, then the top-left
    /// back chevron, which has no label.
    private func returnToTabs() {
        for attempt in 0..<4 {
            let tab = tabButton("Courses")
            if tab.exists && tab.isHittable { return }
            if attempt < 3 {
                let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
                start.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)))
            } else {
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.07, dy: 0.08)).tap()
            }
            settle(1.2)
        }
    }

    /// A tab-bar button: of the buttons starting with the tab's name, the
    /// lowest on screen ("Start" is also the Daily Practice button in German).
    private func tabButton(_ text: String) -> XCUIElement {
        let matches = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", t(text)))
        let lowest = matches.allElementsBoundByIndex.filter { $0.exists }.max { $0.frame.minY < $1.frame.minY }
        return lowest ?? matches.firstMatch
    }

    /// Full-width buttons, top to bottom: answer options in a quiz or a
    /// scenario. Navigation chevrons and tab buttons are narrower.
    private func wideButtons(excluding prefixes: [String]) -> [XCUIElement] {
        let width = app.windows.firstMatch.frame.width
        return app.buttons.allElementsBoundByIndex
            .filter { $0.exists && $0.isHittable && $0.frame.width > width * 0.7 }
            .filter { button in !prefixes.contains { button.label.hasPrefix($0) } }
            .sorted { $0.frame.minY < $1.frame.minY }
    }

    private func staticText(_ english: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", t(english))).firstMatch
    }

    // MARK: - Steps

    private func answer(_ option: String, name: String) {
        let optionButton = button(option)
        XCTAssertTrue(optionButton.waitForExistence(timeout: 10), "Option \"\(option)\" did not appear")
        settle(0.6)
        snap(name)
        optionButton.tap()
        settle(0.6)
        let next = button("Next")
        XCTAssertTrue(next.waitForExistence(timeout: 5), "Next button missing on \(name)")
        next.tap()
    }

    private func continuePastStatistic(name: String) {
        let hint = button("Tap to continue")
        let hintText = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", t("Tap to continue"))).firstMatch
        let appeared = hint.waitForExistence(timeout: 10) || hintText.waitForExistence(timeout: 2)
        XCTAssertTrue(appeared, "Statistic screen \(name) did not appear")
        settle(1.0)
        snap(name)
        if hint.exists && hint.isHittable {
            hint.tap()
        } else if hintText.exists && hintText.isHittable {
            hintText.tap()
        } else {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).tap()
        }
    }

    private func dismissNotificationPromptIfShown() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let english = springboard.buttons["Don\u{2019}t Allow"]
        let deny = english.waitForExistence(timeout: 12) ? english : springboard.buttons["Nicht erlauben"]
        if deny.exists || deny.waitForExistence(timeout: 2) {
            snap("loading-notification-prompt")
            deny.tap()
        }
    }

    // MARK: - Helpers

    /// The first button whose label starts with `text`. The start, not the
    /// whole label, so that a doubled pseudo-language string still matches.
    private func button(_ text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", t(text))).firstMatch
    }

    /// The first button whose label contains `text` anywhere. A plan row's
    /// label starts with its trial badge when it has one.
    private func buttonContaining(_ text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", t(text))).firstMatch
    }

    /// The first element of any kind whose label contains `text`.
    private func anything(containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", t(text))).firstMatch
    }

    private func settle(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// A screenshot outside the numbered sequence: one that only exists in
    /// some builds, so it must not shift the numbers of the ones after it.
    private func snapExtra(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func snap(_ name: String) {
        shot += 1
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = String(format: "%02d-%@", shot, name)
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
