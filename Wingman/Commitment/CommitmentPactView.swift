//
//  CommitmentPactView.swift
//  Wingman
//
//  The screen between the end of onboarding and the paywall — the slot the
//  rating ask used to occupy before App Review rejected 1.07 (27) under
//  guideline 5.6.3 for requesting a rating during onboarding.
//
//  What it is: the user reads a one-line pact built from their own onboarding
//  answer, then presses and holds the Wingman logo to commit. The hold is the
//  point. A tap is a Next button; a hold is effort, and effort is what makes
//  the commitment feel like one rather than like another screen to dismiss.
//
//  Deliberately NOT a fingerprint. Headway's version of this screen holds a
//  Touch ID glyph, and press-and-hold on a fingerprint is UI that mimics
//  system authentication — not a fight worth picking one submission after a
//  Developer Code of Conduct rejection. Praktika and Flo both use their own
//  logo for the identical interaction; so do we.
//
//  Copy lives in `CommitmentPactCopy`, never here.
//

import SwiftUI

struct CommitmentPactView: View {
    @EnvironmentObject var authManager: AuthManager

    /// How long the user must hold before the pact is made. Long enough to
    /// register as deliberate, short enough that nobody lets go thinking the
    /// button is broken.
    private let holdDuration: TimeInterval = 1.2

    /// How far a finger may drift during the hold before it counts as a
    /// scroll and the hold is dropped. Generous, so a thumb resting on glass
    /// never trips it.
    private static let holdSlop: CGFloat = 24

    /// Fill of the ring around the logo, 0…1. Animated to 1 over
    /// `holdDuration` while held, and back to 0 on an early release.
    @State private var holdProgress: CGFloat = 0

    /// True from the moment the hold completes. Latches: the pact is made
    /// once, and re-entering the gesture afterwards must not restart anything.
    @State private var hasCommitted = false

    /// Fires the commit when the hold survives `holdDuration`. Cancelled on
    /// early release, and on disappear so a backgrounded app can't commit for
    /// a user who is no longer looking at the screen.
    @State private var commitWorkItem: DispatchWorkItem?

    /// Guards the gesture's `onChanged`, which fires continuously for the
    /// whole press, from restarting the timer on every callback.
    @State private var isHolding = false

    /// Presses that ended before the ring filled. From the first one on, the
    /// line under the logo says to keep holding instead of naming the
    /// gesture. Also sent with the commit, to see how many people need it.
    @State private var earlyReleases = 0

    /// Briefly true after an early release, to bump the line under the logo
    /// so the changed instruction is noticed.
    @State private var nudgePulse = false

    @State private var appearedAt: Date?

    private let pact = CommitmentPactCopy.pact

    /// `earlyReleases` is for previews and render tests, to draw the
    /// "keep holding" state without a gesture. The app passes nothing.
    init(earlyReleases: Int = 0) {
        _earlyReleases = State(initialValue: earlyReleases)
    }

    /// The name from the optional onboarding screen, or `nil` if it was
    /// skipped. Read once at construction rather than per render: it cannot
    /// change while this screen is up, and the pact re-lettering itself
    /// mid-hold would be the worst possible moment for it.
    private let name = OnboardingNameKey.current

    /// What the user reads. Identical to `pact.headline` when no name was
    /// given.
    private var headline: String {
        CommitmentPactCopy.headline(for: name)
    }

    /// The line under the logo: how to commit, a nudge to keep holding after
    /// an early release, then "Committed."
    private var instruction: String {
        if hasCommitted { return CommitmentPactCopy.committed }
        return earlyReleases > 0
            ? CommitmentPactCopy.keepHolding
            : CommitmentPactCopy.holdInstruction
    }

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - The pact
            //
            // Pinned near the top rather than centred: the pact is what the
            // user reads first, and the empty space between it and the logo is
            // doing work — it separates the promise from the act of making it.
            VStack(spacing: 14) {
                Text(headline)
                    .font(.manropeSemiBold(size: 30))
                    .foregroundColor(.wingmanBlack)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(pact.body)
                    .font(.manropeRegular(size: 16))
                    .foregroundColor(.wingmanBlack.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 28)
            .padding(.top, 56)

            Spacer(minLength: 32)

            // MARK: - Hold-to-commit
            VStack(spacing: 22) {
                logoButton

                // Sized by the taller of the two instructions, so the logo
                // doesn't jump when a two-line one swaps for a one-line one.
                ZStack {
                    Text(CommitmentPactCopy.holdInstruction).hidden()
                    Text(CommitmentPactCopy.keepHolding).hidden()
                    Text(instruction)
                        .foregroundColor(hasCommitted || earlyReleases > 0
                                         ? .wingmanBlack
                                         : .wingmanBlack.opacity(0.55))
                        .scaleEffect(nudgePulse ? 1.08 : 1)
                        .animation(.easeInOut(duration: 0.2), value: hasCommitted)
                        .animation(.easeInOut(duration: 0.2), value: earlyReleases)
                }
                .font(.manropeSemiBold(size: 14))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            }
            .padding(.bottom, 64)
            // The whole lower part of the screen takes the hold, not only the
            // logo. Every earlier onboarding screen has its "Continue" button
            // down here, and replays show people pressing that spot, or the
            // instruction, and getting nothing back.
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        // A finger that travels is scrolling (a translated
                        // pact can make this screen scroll), not holding.
                        if hypot(value.translation.width, value.translation.height) > Self.holdSlop {
                            cancelHold()
                        } else {
                            beginHold()
                        }
                    }
                    .onEnded { value in
                        if hypot(value.translation.width, value.translation.height) > Self.holdSlop {
                            cancelHold()
                        } else {
                            endHold()
                        }
                    }
            )
        }
        // English fits. A longer translated pact used to squeeze the line
        // under the logo down to one cut-off line; now the screen scrolls.
        .scrollsWhenTooTallIfTranslated()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            appearedAt = Date()
            // `pact.headline`, never the rendered one — see
            // `CommitmentPactCopy.headline(for:)`. `personalized` is the flag
            // to segment on instead.
            Analytics.capture(Analytics.Event.commitmentPactViewed, [
                "headline": CommitmentPactCopy.analyticsHeadline,
                "personalized": name != nil
            ])
        }
        .onDisappear {
            commitWorkItem?.cancel()
            commitWorkItem = nil
        }
    }

    // MARK: - Logo

    private var logoButton: some View {
        ZStack {
            // Track — present at rest so the ring reads as something that
            // fills rather than appearing from nowhere on first press.
            Circle()
                .stroke(Color.wingmanBlack.opacity(0.12), lineWidth: 3)
                .frame(width: 132, height: 132)

            Circle()
                .trim(from: 0, to: holdProgress)
                .stroke(
                    Color.wingmanBlack,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 132, height: 132)
                .rotationEffect(.degrees(-90))  // start the fill at 12 o'clock

            Image("wingman_logo_inverted")
                .resizable()
                .scaledToFill()
                .frame(width: 108, height: 108)
                .clipShape(Circle())
                .shadow(
                    color: Color.wingmanBlack.opacity(hasCommitted ? 0.35 : 0.18),
                    radius: hasCommitted ? 18 : 10,
                    x: 0,
                    y: 4
                )
                .scaleEffect(isHolding && !hasCommitted ? 0.94 : 1)
                .animation(.easeOut(duration: 0.18), value: isHolding)
                .animation(.easeOut(duration: 0.3), value: hasCommitted)
        }
        // The press itself is handled by the section around the logo; see
        // `body`.
        // The hold is a nice interaction and a bad requirement: it is not
        // reliably performable with a switch control or VoiceOver's activate
        // gesture. Exposing this as a plain button gives assistive tech a
        // one-step path to the same commit.
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Commit")
        .accessibilityHint(CommitmentPactCopy.holdInstruction)
        .accessibilityAction { commit() }
    }

    // MARK: - Hold handling

    private func beginHold() {
        guard !hasCommitted, !isHolding else { return }
        isHolding = true

        HapticManager.shared.tap()

        withAnimation(.linear(duration: holdDuration)) {
            holdProgress = 1
        }

        let item = DispatchWorkItem { commit() }
        commitWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration, execute: item)
    }

    /// Early release — the user let go before the ring filled. Rewinds rather
    /// than snapping, so a near-miss reads as "not quite" instead of as the
    /// screen rejecting them.
    private func endHold() {
        guard !hasCommitted, isHolding else { return }
        cancelHold()

        // Say why nothing happened: swap in "Keep holding…" and bump it.
        earlyReleases += 1
        HapticManager.shared.warning()
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            nudgePulse = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                nudgePulse = false
            }
        }
    }

    /// Drops a hold in progress without the nudge: for a press that turned
    /// into a scroll, and the first half of `endHold`.
    private func cancelHold() {
        guard !hasCommitted, isHolding else { return }
        isHolding = false

        commitWorkItem?.cancel()
        commitWorkItem = nil

        withAnimation(.easeOut(duration: 0.25)) {
            holdProgress = 0
        }
    }

    private func commit() {
        guard !hasCommitted else { return }
        hasCommitted = true
        isHolding = false
        commitWorkItem = nil

        HapticManager.shared.success()

        withAnimation(.easeOut(duration: 0.2)) {
            holdProgress = 1
        }

        var properties: [String: Any] = [
            "headline": CommitmentPactCopy.analyticsHeadline,
            "personalized": name != nil,
            "early_releases": earlyReleases
        ]
        if let appearedAt {
            properties["time_on_screen_seconds"] = Analytics.elapsedSeconds(since: appearedAt)
        }
        Analytics.capture(Analytics.Event.commitmentPactCommitted, properties)

        // Beat on "Committed." before the paywall replaces the screen. Without
        // it the success haptic and the route change land in the same frame and
        // the commitment never registers as having happened.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            authManager.completeCommitmentPact()
        }
    }
}

#Preview {
    CommitmentPactView()
        .environmentObject(AuthManager())
}

#Preview("After an early release") {
    CommitmentPactView(earlyReleases: 1)
        .environmentObject(AuthManager())
}
