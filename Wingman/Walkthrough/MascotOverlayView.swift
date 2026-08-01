//
//  MascotOverlayView.swift
//  Wingman
//
//  The visible half of the first-run walkthrough. See docs/walkthrough-plan.md.
//
//  Layered into MainTabView's ZStack above the tab bar, and rendered only when
//  `TabBarVisibilityManager.isVisible` — that flag is already the app's signal
//  for "the user is on a tab surface, not inside content", so it keeps the
//  mascot off the top of PracticeGame and LessonView, which are pushed inside
//  the TabView and would otherwise draw underneath it.
//
//  The app stays visible behind the scrim on purpose. The point of the
//  walkthrough is to show someone the thing they are being asked to pay for,
//  not to cover it up.
//

import SwiftUI

struct MascotOverlayView: View {

    @EnvironmentObject private var walkthrough: WalkthroughCoordinator

    /// Read so the closing beat can stop promising a free lesson the user
    /// would not be able to reach. Observed rather than read inline because
    /// `/decide` can answer mid-session.
    @StateObject private var featureFlags = FeatureFlags.shared

    /// The welcome is two beats of copy in one step. Kept local because the
    /// scrim blocks interaction throughout `welcome`, so nothing can hide the
    /// tab bar and tear this view down mid-read.
    @State private var welcomePage = 0

    var body: some View {
        if let beat {
            ZStack {
                scrim
                bubbleLayer(beat)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.25), value: walkthrough.step)
            .animation(.easeInOut(duration: 0.2), value: walkthrough.nudge)
            // This is the longest single block of copy in the app, and nothing
            // above MainTabView applies the ceiling. Matches the treatment on
            // every other full-screen surface (GameCompleteView, the sheets).
            .appDynamicTypeCeiling()
        }
    }

    // MARK: - Scrim

    /// Dims the app behind the mascot.
    ///
    /// Hit-testing is the load-bearing part, not the dimming. Two beats ask the
    /// user to *do* something in the app — tap the scenario, scroll the courses
    /// — and a scrim that swallowed those taps would make the instruction
    /// impossible to follow. Those beats dim less and pass touches straight
    /// through; the read-only beats block, which is also what stops an
    /// off-script tap during `welcome` from needing a nudge at all.
    private var scrim: some View {
        Color.black
            .opacity(blocksInteraction ? 0.55 : 0.15)
            .ignoresSafeArea()
            .allowsHitTesting(blocksInteraction)
    }

    private var blocksInteraction: Bool {
        if walkthrough.nudge != nil { return true }
        switch walkthrough.step {
        case .scenarioPrompt, .lessonsTour: return false
        default: return true
        }
    }

    // MARK: - Mascot + bubble

    private func bubbleLayer(_ beat: Beat) -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            speechBubble(beat)
                .padding(.horizontal, 20)
                // On the two pass-through beats the bubble has no button, and
                // a bubble that swallows taps would sit between the user and
                // the thing they were just told to tap. The scrim already
                // passes touches; this stops the bubble from undoing that.
                .allowsHitTesting(beat.action != nil)

            mascot
                .padding(.leading, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                // Decorative, and 148×240pt of it sits over the bottom-left of
                // the content. An Image is hit-testable across its whole frame
                // regardless of transparency, so without this it would block
                // taps there on every beat.
                .allowsHitTesting(false)

            // Clears the tab bar so the mascot stands on it rather than
            // behind it.
            Spacer().frame(height: 92)
        }
    }

    /// The asset is a 2048² square whose figure occupies roughly the left 55%
    /// and runs to the bottom edge — it is not a centred bust. Fitting the
    /// square to a height and then narrowing the frame crops the empty right
    /// half away; without that the figure renders small and pushed off-centre.
    private var mascot: some View {
        Image("scenario_user")
            .resizable()
            .scaledToFit()
            .frame(height: 240)
            .frame(width: 148, alignment: .leading)
            .clipped()
            .accessibilityHidden(true)
    }

    private func speechBubble(_ beat: Beat) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(beat.text)
                .font(.manropeMedium(size: 17))
                .foregroundColor(.wingmanBlack)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let action = beat.action {
                Button(action: beat.perform) {
                    Text(action)
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(.wingmanWhiteFF)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.wingmanBlack)
                        .cornerRadius(5)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ScalePressStyle())
            }
        }
        .padding(20)
        .background(Color.wingmanWhiteFF)
        .cornerRadius(5)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.wingmanBlack.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 18, y: 6)
    }

    // MARK: - Script

    private struct Beat {
        let text: String
        /// `nil` means there is no way forward from the bubble — the user has
        /// to act in the app. Only `scenarioPrompt` does this, and that is the
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
            return welcomePage == 0
                ? Beat(text: Self.welcomeOne, action: "Go on", perform: { welcomePage = 1 })
                : Beat(text: Self.welcomeTwo, action: "Show me", perform: walkthrough.advance)

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
    // first, no jargon. Deliberately kept in the second person rather than
    // leaning on the mascot's identity — the asset is the player's own avatar
    // from the scenario game, so "this figure is me" is a reading some users
    // will have, and copy that fights it would be confusing.

    private static let welcomeOne = """
        Most guys don't freeze because they're bad with women. They freeze \
        because they've never practised.
        """

    private static let welcomeTwo = """
        So that's what this is. Real conversations you can get wrong safely, \
        until getting them right stops feeling like luck.
        """

    private static let scenarioPrompt = """
        Start here. She's at the bar, you've got an opening. Play it out — \
        there's no wrong answer you can't take back.
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
