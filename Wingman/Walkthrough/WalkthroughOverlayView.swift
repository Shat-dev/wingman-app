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
            // Sized by width like SplashView does (200pt there), not by
            // height — the wordmark is wide and short, so a height constraint
            // renders it postage-stamp small.
            Image("wingman_logo")
                .resizable()
                .scaledToFit()
                .frame(width: 130)
                .frame(maxWidth: .infinity, alignment: .center)
                .accessibilityHidden(true)

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
            return Beat(text: Self.welcome, action: "Next", perform: walkthrough.advance)

        // No card at all. The scenario list carries the whole instruction: the
        // tab bar is locked, every other scenario is progression-locked, and
        // the one they are meant to open is pulsing. A card here would only
        // stand between the user and the single thing they can do.
        case .scenarioPrompt:
            return nil

        case .scenarioDone:
            return Beat(text: Self.congratulations, action: "Next", perform: walkthrough.advance)

        case .lessonsTour:
            return Beat(text: Self.coursesTour, action: "Next", perform: walkthrough.advance)

        case .benefits:
            return Beat(text: Self.signOff, action: "Next", perform: walkthrough.advance)

        case .dormant, .scenarioRunning, .finished:
            return nil
        }
    }

    // MARK: - Copy
    //
    // Voice follows AppStrings.Onboarding: plain, second person, outcome
    // first, no jargon.

    // Verbatim, including punctuation. No em dashes anywhere in walkthrough
    // copy — commas only.

    private static let welcome = """
        Hey, welcome to Wingman. Let's dive into a practice scenario.
        """

    private static let congratulations = """
        Nice work. That's the whole skill, read the moment, pick your line, \
        adjust. It gets easier every time.
        """

    private static let coursesTour = """
        Over here is Courses, this is where the rest of it comes from. \
        Mindset, approaching, flirting, follow-up, all in short lessons.
        """

    private static let signOff = """
        That's everything. Go put it to use, we're rooting for you.
        """

    private static func nudgeText(_ nudge: WalkthroughCoordinator.Nudge) -> String {
        switch nudge {
        case .lesson:
            // Deliberately does not promise the free lesson. The script no
            // longer mentions it anywhere, and a nudge is the wrong place to
            // introduce an offer the closing beat won't back up.
            return "Almost done, you'll be free to explore in a second."
        case .dailyPractice:
            return "One thing at a time. Play the scenario first."
        case .lockedScenario:
            return "That one's further down the line. Start with the first."
        }
    }
}
