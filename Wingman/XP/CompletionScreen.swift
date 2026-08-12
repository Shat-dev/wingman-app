//
//  CompletionScreen.swift
//  Wingman
//
//  The shared reward moment shown after a lesson, a scenario, or daily
//  practice.
//
//  DESIGN NOTES (the reasoning, so the next edit does not undo it)
//
//  Animate the total, state the delta. Rolling 0→35 is 35 units of travel and
//  reads fussy; rolling 300→335 gives real motion and reframes the reward as
//  "your body of work grew" rather than "you got points". That is the Strava
//  move, not the Duolingo one, and it is what suits an anti-hype brand.
//
//  No particles, no sound, no bounce. Confetti is borrowed celebration with no
//  relationship to the content, and on an off-white field it is the loudest
//  thing that could possibly happen. Sound is worse than a taste problem here:
//  a man practising social confidence is often in public, and a chime announces
//  the self-improvement app to the room. The celebratory weight is carried by
//  the counter's deceleration and by the haptic when it lands.
//
//  XP arrives over the network, so the sequence cannot assume it at t=0. The
//  intro beats always run; the XP block animates in at its slot if the award
//  has already landed, or whenever it arrives, or never. Nothing looks broken
//  in the last case.
//
//  Continue is fully opaque and fully tappable from the first frame. It is
//  deliberately outside the animation sequence — a button that fades in reads
//  as not-yet-tappable, and anyone who wants to skip the moment should never
//  be made to wait for it.
//

import SwiftUI

/// Beat timings in seconds.
///
/// File scope rather than nested, because `CompletionScreen` is generic over
/// its detail slot and Swift does not allow static stored properties inside a
/// generic type.
///
/// The whole sequence lands at ~1.26s, or ~1.56s on a level-up. Both sit inside
/// the 2s budget with room to spare.
private enum T {
    static let markIn = 0.26
    static let titleAt = 0.12,  titleIn = 0.22
    static let detailAt = 0.98, detailIn = 0.22
    static let xpAt = 0.52
    static let deltaIn = 0.20
    static let rollDelay = 0.04
    static let roll = 0.70, rollMilestone = 1.00
    static let levelDelay = 0.22, levelIn = 0.32
}

struct CompletionScreen<Detail: View>: View {

    let title: String
    /// The confirmed award, or nil while in flight / on a replay. Never
    /// optimistic: the screen must not claim XP the server did not grant.
    let award: XPStore.Award?
    let continueTitle: String
    let onContinue: () -> Void
    let detail: () -> Detail

    /// Explicit rather than memberwise: a `let` with a default value is omitted
    /// from the synthesised initialiser entirely, so `continueTitle` would have
    /// been required at every call site.
    init(
        title: String,
        award: XPStore.Award?,
        continueTitle: String = "Continue",
        onContinue: @escaping () -> Void,
        @ViewBuilder detail: @escaping () -> Detail
    ) {
        self.title = title
        self.award = award
        self.continueTitle = continueTitle
        self.onContinue = onContinue
        self.detail = detail
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Reveal state

    @State private var showMark = false
    @State private var showTitle = false
    @State private var showXP = false
    @State private var showLevel = false
    @State private var showDetail = false
    @State private var displayedTotal: Double = 0
    @State private var hasRunIntro = false
    @State private var hasRunXP = false

    /// Cleared the moment the user leaves, so scheduled beats stop.
    ///
    /// Continue is live from the first frame, which means the sequence is often
    /// still mid-flight when the screen goes away. Without this the roll and
    /// settle haptics keep firing on whatever screen the user landed on next —
    /// skipping the moment has to actually skip it, not follow them out.
    @State private var isActive = true

    /// Standard ease-out cubic. Decelerates into the final value and **never
    /// overshoots** — overshoot past the target is the slot-machine tell.
    private func rollCurve(_ duration: Double) -> Animation {
        .timingCurve(0.215, 0.61, 0.355, 1, duration: duration)
    }

    // MARK: - Derived XP state

    /// Exact, because `Award` carries both halves. No store change needed.
    private var previousTotal: Int {
        guard let award else { return 0 }
        return max(award.totalAfter - award.amount, 0)
    }

    private var levelAfter: XPLevel.Progress {
        XPLevel.progress(for: award?.totalAfter ?? 0)
    }

    /// The only milestone XP alone can produce. Streak and module milestones
    /// need data this screen does not receive yet.
    private var didLevelUp: Bool {
        guard award != nil else { return false }
        return levelAfter.level > XPLevel.progress(for: previousTotal).level
    }

    private var rollDuration: Double {
        didLevelUp ? T.rollMilestone : T.roll
    }

    /// The mark dominates the layout, and the XP block and level bar are new
    /// weight below it. At the previous 291pt this overflowed SE-class devices.
    private var markSize: CGFloat {
        UIScreen.isSmallPhone ? 150 : 220
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 12)

                Image("checklist")
                    .resizable()
                    .scaledToFit()
                    .frame(width: markSize, height: markSize)
                    .allowsHitTesting(false)
                    .opacity(showMark ? 1 : 0)
                    .scaleEffect(showMark ? 1 : 0.96)

                Text(title)
                    .font(.manropeSemiBold(size: 28))
                    .foregroundColor(.wingmanBlack)
                    .kerning(-0.3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 8)

                xpBlock
                    .padding(.top, 24)

                detail()
                    .padding(.top, 20)
                    .opacity(showDetail ? 1 : 0)

                Spacer(minLength: 16)

                Button(action: {
                    isActive = false
                    HapticManager.shared.tapStrong()
                    onContinue()
                }) {
                    Text(continueTitle)
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.wingmanBlack)
                        .cornerRadius(5)
                }
                .buttonStyle(ScalePressStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
        }
        .onAppear(perform: runIntro)
        .onDisappear { isActive = false }
        .onChange(of: award) { newValue in
            guard newValue != nil, isActive else { return }
            runXPReveal()
        }
    }

    // MARK: - XP block

    @ViewBuilder
    private var xpBlock: some View {
        // Reserves no space until there is a confirmed award, so a replay or an
        // in-flight request leaves the layout exactly as it was.
        if let award {
            VStack(spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("+\(award.amount)")
                        .font(.manropeSemiBold(size: 20))
                        .monospacedDigit()
                    Text("XP")
                        .font(.manropeMedium(size: 13))
                        .opacity(0.7)
                }
                // The single accent. Green already means "correct" in
                // onboarding and the quiz, so the positive outcome is
                // semantically consistent. It stays rather than flashing —
                // a flash-and-fade reads as a toast notification.
                .foregroundColor(.customGreen)
                .opacity(showXP ? 1 : 0)
                .offset(y: showXP ? 0 : 6)

                RollingTotal(value: displayedTotal)
                    .opacity(showXP ? 1 : 0)

                levelRow
                    .padding(.top, 6)
                    .opacity(showLevel ? 1 : 0)
            }
        }
    }

    @ViewBuilder
    private var levelRow: some View {
        VStack(spacing: 8) {
            Text(didLevelUp ? "Level \(levelAfter.level) reached." : "Level \(levelAfter.level)")
                .font(didLevelUp ? .manropeSemiBold(size: 14) : .manropeMedium(size: 13))
                .foregroundColor(didLevelUp ? .wingmanBlack : .gray)

            // The rule doubles as the level bar. A horizontal rule is already
            // print vocabulary, so it earns its place twice.
            //
            // On a level-up it goes full-bleed, breaking the 20pt margin. That
            // is the one time the layout breaks its own grid, and it is the
            // whole milestone treatment — no particles, no colour change.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 4)
                    Capsule()
                        .fill(Color.wingmanBlack)
                        .frame(width: geo.size.width * (showLevel ? levelAfter.fraction : 0), height: 4)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, didLevelUp ? 0 : 40)
        }
    }

    // MARK: - Sequencing

    private func runIntro() {
        guard !hasRunIntro else { return }
        hasRunIntro = true

        guard !reduceMotion else {
            // Reduce Motion removes movement, not feedback. Everything is
            // simply present; the haptic ladder still runs, compressed, because
            // stripping it would take the payoff away from exactly the people
            // relying on non-visual feedback.
            showMark = true; showTitle = true; showDetail = true
            runXPReveal()
            return
        }

        withAnimation(.easeOut(duration: T.markIn)) { showMark = true }
        after(T.titleAt)  { withAnimation(.easeOut(duration: T.titleIn))  { showTitle = true } }
        after(T.detailAt) { withAnimation(.easeOut(duration: T.detailIn)) { showDetail = true } }

        if award != nil {
            after(T.xpAt) { runXPReveal() }
        }
    }

    private func runXPReveal() {
        guard !hasRunXP, let award else { return }
        hasRunXP = true

        displayedTotal = Double(previousTotal)

        guard !reduceMotion else {
            showXP = true
            showLevel = true
            displayedTotal = Double(award.totalAfter)
            HapticManager.shared.tap()
            after(0.20) { settleHaptic() }
            return
        }

        withAnimation(.easeOut(duration: T.deltaIn)) { showXP = true }
        HapticManager.shared.tap()

        after(T.rollDelay) {
            withAnimation(rollCurve(rollDuration)) {
                displayedTotal = Double(award.totalAfter)
            }
        }

        after(T.rollDelay + T.levelDelay) {
            withAnimation(.easeInOut(duration: T.levelIn)) { showLevel = true }
        }

        // Scheduled rather than detected: animation-completion callbacks are
        // less reliable than the duration we just asked for.
        after(T.rollDelay + rollDuration) { settleHaptic() }
    }

    /// The payoff beat. Deliberately one haptic at the landing, never one per
    /// digit — a haptic ladder tracking the counter is exactly the slot machine.
    private func settleHaptic() {
        if didLevelUp {
            HapticManager.shared.success()
        } else {
            HapticManager.shared.threshold()
        }
    }

    /// Runs `work` after `delay`, unless the user has already left.
    private func after(_ delay: Double, _ work: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard isActive else { return }
            work()
        }
    }
}

// MARK: - Rolling total

/// Counts to its value with whatever animation the caller applies.
///
/// `monospacedDigit` matters: without it the text re-centres on every digit
/// change and the number visibly jitters while rolling.
private struct RollingTotal: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("\(Int(value.rounded())) XP")
            .font(.manropeMedium(size: 14))
            .monospacedDigit()
            .foregroundColor(.gray)
    }
}

// MARK: - Convenience for screens with nothing below the XP block

extension CompletionScreen where Detail == EmptyView {
    init(
        title: String,
        award: XPStore.Award?,
        continueTitle: String = "Continue",
        onContinue: @escaping () -> Void
    ) {
        self.init(
            title: title,
            award: award,
            continueTitle: continueTitle,
            onContinue: onContinue,
            detail: { EmptyView() }
        )
    }
}

#Preview("Normal award") {
    CompletionScreen(
        title: "Lesson complete.",
        award: XPStore.Award(source: .lesson, amount: 35, totalAfter: 335),
        onContinue: {}
    )
}

#Preview("Level up") {
    CompletionScreen(
        title: "Lesson complete.",
        award: XPStore.Award(source: .lesson, amount: 40, totalAfter: 260),
        onContinue: {}
    )
}

#Preview("No award yet (offline or replay)") {
    CompletionScreen(
        title: "Scenario complete.",
        award: nil,
        onContinue: {}
    )
}
