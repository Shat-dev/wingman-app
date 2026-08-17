//
//  WalkthroughOverlayView.swift
//  Wingman
//
//  The visible half of the first-run walkthrough. See docs/walkthrough-plan.md.
//
//  One treatment for every beat: a card pinned just above the tab bar over a
//  dimmed app. No mascot — the character was tried in two forms (small figure
//  beside the copy, then large on a white stage) and in both it competed with
//  the product it was meant to be selling. What actually persuades is the app
//  behind the card, so the card stays small and the app stays visible.
//
//  That reasoning is also why the card sits at the bottom rather than the
//  middle, and why it borrows its shape from `DialogueContentView` — the box a
//  scenario's dialogue is read in. Centred, with a wordmark and a full-width
//  Next button, it covered the very list the copy was pointing at; at the
//  bottom the first scenario card stays on screen while the instruction is
//  read, and the treatment is one the user meets again inside the scenario.
//
//  Layered into MainTabView's ZStack above the tab bar, and rendered only when
//  `TabBarVisibilityManager.isVisible` — that flag is already the app's signal
//  for "the user is on a tab surface, not inside content", so it keeps the
//  overlay off the top of PracticeGame and LessonView, which are pushed inside
//  the TabView and would otherwise draw underneath it.
//

import SwiftUI

struct WalkthroughOverlayView: View {

    /// Measured height of `CustomTabBar`, supplied by MainTabView.
    ///
    /// Measured rather than assumed because the bar's own height is device
    /// dependent — `CustomTabBar.bottomPadding()` tucks it into the home
    /// indicator on phones that have one and pads it outward on phones that
    /// don't, so any constant here would clear the bar on one device and
    /// overlap it on another.
    let tabBarHeight: CGFloat

    @EnvironmentObject private var walkthrough: WalkthroughCoordinator

    var body: some View {
        if let beat {
            ZStack(alignment: .bottom) {
                scrim
                card(beat)
                    .padding(.horizontal, 16)
                    .padding(.bottom, tabBarHeight + 14)
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
        // The tour beat asks the user to scroll the course list while its card
        // is up, so it has to let touches through.
        //
        // `scenarioPrompt` no longer needs to: its card can be tapped through,
        // and once that happens `beat` is nil so nothing renders at all, scrim
        // included. The scenario card is fully tappable from that point.
        case .lessonsTour: return false
        default: return true
        }
    }

    // MARK: - Card

    private func card(_ beat: Beat) -> some View {
        Button {
            HapticManager.shared.tap()
            beat.advance?()
        } label: {
            VStack(spacing: 10) {
                Text(beat.text)
                    .font(.manropeMedium(size: 16))
                    .foregroundColor(.wingmanBlack)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)

                if beat.advance != nil {
                    Text(Self.continueHint)
                        .font(.manropeMedium(size: 13))
                        .foregroundColor(.wingmanBlack.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 14)
            .background(Color.wingmanWhiteFF)
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.wingmanBlack.opacity(0.10), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScalePressStyle(pressedScale: 0.98))
        // On a beat with no way forward there is nothing here to tap, and
        // swallowing touches would put the card between the user and what they
        // were just told to open.
        .allowsHitTesting(beat.advance != nil)
    }

    // MARK: - Script

    private struct Beat {
        let text: String
        /// `nil` means there is no way forward from the card — the user has to
        /// act in the app. Nothing uses it today, and the card drops its
        /// "Tap to continue" hint and its hit testing when it is nil, which is
        /// what keeps that a real option rather than a dead branch.
        let advance: (() -> Void)?
    }

    private var beat: Beat? {
        if let nudge = walkthrough.nudge {
            return Beat(
                text: Self.nudgeText(nudge),
                advance: { walkthrough.dismissNudge() }
            )
        }

        switch walkthrough.step {
        case .welcome:
            return Beat(text: Self.welcome, advance: walkthrough.advance)

        // Tapping through dismisses the card but does NOT advance the script —
        // tapping the pulsing scenario is still the only way forward, which is
        // the one hard constraint. `acknowledgeScenarioPrompt()` leaves the
        // step alone for exactly that reason.
        //
        // The card also does a second job. This beat arrives at the same moment
        // as a tab switch, and `TabView` realises the Scenarios tab for the
        // first time there, a first layout the previous tab stays visible
        // through. With nothing rendered on this beat the eye had no anchor
        // across that switch, so the swap read as a lag.
        case .scenarioPrompt:
            guard !walkthrough.scenarioPromptAcknowledged else { return nil }
            return Beat(
                text: Self.scenarioPrompt,
                advance: walkthrough.acknowledgeScenarioPrompt
            )

        case .scenarioDone:
            return Beat(text: Self.congratulations, advance: walkthrough.advance)

        case .lessonsTour:
            return Beat(text: Self.coursesTour, advance: walkthrough.advance)

        case .benefits:
            return Beat(text: Self.signOff, advance: walkthrough.advance)

        case .dormant, .scenarioRunning, .finished:
            return nil
        }
    }

    // MARK: - Copy
    //
    // Voice follows AppStrings.Onboarding: plain, second person, outcome
    // first, no jargon.

    /// Verbatim the wording a scenario's dialogue box uses, because this card
    /// now looks like one and is advanced the same way.
    private static let continueHint = "Tap to continue"

    // Verbatim, including punctuation. No em dashes anywhere in walkthrough
    // copy — commas only.

    private static let welcome = """
        Hey, welcome to Wingman. Let's dive into a practice scenario.
        """

    private static let scenarioPrompt = """
        This is where you practise. Each scenario drops you into a real \
        moment and you choose what to say. Start with the first one.
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

// MARK: - Tab bar measurement

/// Carries `CustomTabBar`'s measured height from MainTabView to the walkthrough
/// card, which sits directly above it. See `WalkthroughOverlayView.tabBarHeight`.
struct WalkthroughTabBarHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
