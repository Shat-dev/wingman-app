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
//  bottom the courses and scenarios the copy names stay on screen while it is
//  read, and the treatment is one the user meets again inside a scenario.
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
    /// One beat asks the user to *do* something in the app: scroll the course
    /// list. A scrim that swallowed those taps would make the instruction
    /// impossible to follow.
    ///
    /// Every other beat blocks, the two Scenarios beats included. Their copy
    /// invites the user to play something, but it invites them to do it *after*
    /// the tour: opening a scenario mid-script would have to finish the
    /// walkthrough to get the scrim out of the way, and finishing flips
    /// `hasCompletedFreeDemo`, which moves RootView from branch 4b to 4d and
    /// rebuilds `MainTabView` — dismissing the `PracticeGame` the user just
    /// opened. Blocking costs one extra tap, and the list is fully live a moment
    /// later on the same tab, which is where the script leaves them.
    private var blocksInteraction: Bool {
        // A nudge answers a tap the user just made; blocking until they
        // acknowledge it keeps the script from being talked over.
        if walkthrough.nudge != nil { return true }

        switch walkthrough.step {
        case .coursesTour: return false
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
                    Text(beat.hint)
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
        /// hint and its hit testing when it is nil, which is what keeps that a
        /// real option rather than a dead branch.
        let advance: (() -> Void)?
        /// The trailing affordance. Defaults to the dialogue box's wording,
        /// which is the point of the treatment; the closing beat overrides it
        /// because "continue" would promise a card that isn't coming.
        var hint: String = WalkthroughOverlayView.continueHint
    }

    private var beat: Beat? {
        if let nudge = walkthrough.nudge {
            return Beat(
                text: Self.nudgeText(nudge),
                advance: { walkthrough.dismissNudge() }
            )
        }

        // One card per tab, in script order, then a sign-off. Every one of them
        // advances from the card itself — see `WalkthroughCoordinator.advance()`.
        switch walkthrough.step {
        case .welcome:
            return Beat(text: Self.welcome, advance: walkthrough.advance)

        case .coursesTour:
            return Beat(text: Self.coursesTour, advance: walkthrough.advance)

        // The only place the scenario is mentioned, and it is mentioned rather
        // than demanded: this used to be a gate the user could not pass without
        // playing a scenario end to end, and that gate was the single worst
        // step in the funnel.
        case .scenarioTour:
            return Beat(text: Self.scenarioTour, advance: walkthrough.advance)

        // Named as the last card by its own copy, and its hint is a call to
        // action rather than a navigation word, because what follows is a
        // sign-off rather than another thing to read.
        case .progressTour:
            return Beat(
                text: Self.progressTour,
                advance: walkthrough.advance,
                hint: Self.startFillingHint
            )

        case .signOff:
            return Beat(
                text: Self.signOff,
                advance: walkthrough.advance,
                hint: Self.finishHint
            )

        case .dormant, .finished:
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

    /// The Profile card. A call to action rather than a navigation word, because
    /// what follows it is a sign-off rather than another card to read.
    private static let startFillingHint = "Start filling it"

    /// The closing card. "Continue" would point at a card that isn't coming.
    private static let finishHint = "Tap to finish"

    // Verbatim, including punctuation and line breaks. No em dashes anywhere in
    // walkthrough copy — commas only.
    //
    // One card per tab in the order the script visits them (Home, Courses,
    // Scenarios, Profile) and then a sign-off back on Scenarios. Each card says
    // what the tab is for and nothing else; none of them asks the user to do
    // anything.
    //
    // The line break inside each one is intentional: a short line that names the
    // tab, then the line that says why it matters. Continuations are marked with
    // a trailing `\` so only the deliberate breaks survive into the string.

    private static let welcome = """
        Welcome to Wingman. This is home.
        Daily practice keeps you sharp. The log fills with moments you took, \
        not replayed.
        """

    private static let coursesTour = """
        Courses. Mindset, approaching, flirting, follow-up.
        Short lessons that build the man who moves, not the one who freezes.
        """

    private static let scenarioTour = """
        And this is where you practise.
        Bookstore, gym, coffee shop. Choose what to say, see what happens.
        """

    private static let progressTour = """
        Last one. This one is you.
        Empty today. In a month it either tells a story or it doesn't.
        """

    private static let signOff = """
        Good luck, we're rooting for you.
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
