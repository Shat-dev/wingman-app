//
//  WalkthroughOverlayView.swift
//  Wingman
//
//  The visible half of the first-run walkthrough. See docs/walkthrough-plan.md.
//
//  One treatment for every beat: a card in the middle of the screen over a
//  dimmed app. No mascot — the character was tried in two forms (small figure
//  beside the copy, then large on a white stage) and in both it competed with
//  the product it was meant to be selling. What actually persuades is the app
//  behind the card, so the card stays small and the app stays visible.
//
//  Layered into MainTabView's ZStack above the tab bar, and rendered only when
//  `TabBarVisibilityManager.isVisible` — that flag is already the app's signal
//  for "the user is on a tab surface, not inside content", so it keeps the
//  overlay off the top of PracticeGame and LessonView, which are pushed inside
//  the TabView and would otherwise draw underneath it.
//

import SwiftUI

struct WalkthroughOverlayView: View {

    @EnvironmentObject private var walkthrough: WalkthroughCoordinator

    /// Read so the closing beat can stop promising a free lesson the user
    /// would not be able to reach. Observed rather than read inline because
    /// `/decide` can answer mid-session.
    @StateObject private var featureFlags = FeatureFlags.shared

    var body: some View {
        if let beat {
            ZStack {
                scrim
                card(beat)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: walkthrough.step)
            .animation(.easeInOut(duration: 0.2), value: walkthrough.nudge)
            // The longest copy in the app, and nothing above MainTabView
            // applies the ceiling. Matches every other full-screen surface.
            .appDynamicTypeCeiling()
        }
    }

    // MARK: - Scrim

    /// Dims the app without hiding it. The app behind is the argument the
    /// walkthrough is making, so it stays legible.
    private var scrim: some View {
        Color.black
            .opacity(0.45)
            .ignoresSafeArea()
            .allowsHitTesting(blocksInteraction)
    }

    /// Hit-testing, not appearance — every beat looks identical.
    ///
    /// Two beats ask the user to *do* something in the app: tap the scenario
    /// card, scroll the course list. A scrim that swallowed those taps would
    /// make the instruction impossible to follow, and `scenarioPrompt` has no
    /// button, so there would be no way forward at all.
    private var blocksInteraction: Bool {
        // A nudge answers a tap the user just made; blocking until they
        // acknowledge it keeps the script from being talked over.
        if walkthrough.nudge != nil { return true }

        switch walkthrough.step {
        case .scenarioPrompt, .lessonsTour: return false
        default: return true
        }
    }

    // MARK: - Card

    private func card(_ beat: Beat) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(beat.text)
                .font(.manropeMedium(size: 18))
                .foregroundColor(.wingmanBlack)
                .lineSpacing(5)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let action = beat.action {
                primaryButton(action, perform: beat.perform)
            }
        }
        .padding(24)
        .background(Color.wingmanWhiteFF)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.wingmanBlack.opacity(0.10), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 24, y: 10)
        .padding(.horizontal, 28)
        // On a beat with no button there is nothing here to tap, and swallowing
        // touches would put the card between the user and what they were just
        // told to open.
        .allowsHitTesting(beat.action != nil)
    }

    private func primaryButton(
        _ title: String,
        perform: @escaping () -> Void
    ) -> some View {
        Button(action: perform) {
            Text(title)
                .font(.manropeSemiBold(size: 16))
                .foregroundColor(.wingmanWhiteFF)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.wingmanBlack)
                .cornerRadius(5)
                .contentShape(Rectangle())
        }
        .buttonStyle(ScalePressStyle())
    }

    // MARK: - Script

    private struct Beat {
        let text: String
        /// `nil` means there is no way forward from the card — the user has to
        /// act in the app. Only `scenarioPrompt` does this, and that is the
        /// plan's one hard constraint: the scenario has no skip.
        let action: String?
        let perform: () -> Void
    }

    private var beat: Beat? {
        if let nudge = walkthrough.nudge {
            return Beat(
                text: Self.nudgeText(nudge),
                action: "Got it",
                perform: { walkthrough.dismissNudge() }
            )
        }

        switch walkthrough.step {
        case .welcome:
            return Beat(text: Self.welcome, action: "Show me", perform: walkthrough.advance)

        case .scenarioPrompt:
            return Beat(text: Self.scenarioPrompt, action: nil, perform: {})

        case .scenarioDone:
            return Beat(text: Self.congratulations, action: "What's next", perform: walkthrough.advance)

        case .lessonsTour:
            return Beat(
                text: walkthrough.didSkipScenario ? Self.lessonsTourSkipped : Self.lessonsTour,
                action: "Got it",
                perform: walkthrough.advance
            )

        case .benefits:
            return Beat(text: benefitsText, action: "Let's go", perform: walkthrough.advance)

        case .dormant, .scenarioRunning, .finished:
            return nil
        }
    }

    // MARK: - Copy
    //
    // Voice follows AppStrings.Onboarding: plain, second person, outcome
    // first, no jargon.

    /// One beat, not three.
    ///
    /// The beats that were cut argued that the app is a gym for social skills —
    /// the same argument paywall #1's carousel already makes, to the same user,
    /// minutes earlier. This screen only runs for someone who read those twelve
    /// bullets and said no, so repeating them cannot move anything. The scenario
    /// is the only new information available, and every tap before it is a tax
    /// on reaching it.
    private static let welcome = """
        Hey — welcome to Wingman. Quickest way to show you what this is: \
        play one.
        """

    private static let scenarioPrompt = """
        Let's dive into a practice scenario. These prepare you for real life, \
        so you don't have to fumble first in the real world.
        """

    private static let congratulations = """
        That's the whole skill — read the moment, pick your line, adjust. You \
        just did it once. Do it fifteen more times and it's who you are.
        """

    // The tour beats say "have a look", never "have a go". They used to invite
    // a tap and then refuse it, which spends the user's goodwill at the exact
    // moment the script is trying to earn it.

    private static let lessonsTour = """
        The scenarios get easier because of these. Mindset, opening, flirting, \
        escalation — short lessons, each one feeding the next. Have a look \
        down the list; you'll pick one in a second.
        """

    /// Shown when the scenario beat was skipped, so it can't refer back to a
    /// scenario the user just played.
    private static let lessonsTourSkipped = """
        This is where the rest of it comes from. Mindset, opening, flirting, \
        escalation — short lessons, each one feeding the next. Have a look \
        down the list; you'll pick one in a second.
        """

    /// Counts come from the live catalogue rather than from literals. The
    /// scenario table is edited without touching this file, and the lesson
    /// totals live in the bundled course data — a hardcoded "15 scenarios"
    /// goes quietly wrong the first time either changes.
    ///
    /// The closing promise is dropped when the post-demo wall is hard: in that
    /// mode a non-buyer can never open a lesson, so "on me either way" would
    /// be false. The flag and this sentence are a pair.
    private var benefitsText: String {
        let scenarios = walkthrough.scenarioCount.map { "\($0) scenarios" } ?? "every scenario"
        let lessons = walkthrough.lessonCount.map { "\($0) lessons" } ?? "the full course library"

        var text = "Here's what's waiting: \(scenarios), \(lessons), "
            + "daily practice to keep you sharp, and a log of every real "
            + "approach you make so you can watch yourself get better."

        if !featureFlags.postDemoWallIsHard {
            text += " Your first lesson is on me either way."
        }
        return text
    }

    private static func nudgeText(_ nudge: WalkthroughCoordinator.Nudge) -> String {
        switch nudge {
        case .lesson:
            // Names what happens next instead of just refusing. The user is one
            // beat from being handed this exact thing.
            return "Almost — one more thing, then your first lesson's on me."
        case .dailyPractice:
            return "One thing at a time. Play the scenario first."
        case .lockedScenario:
            return "That one's further down the line. Start with the first."
        }
    }
}
