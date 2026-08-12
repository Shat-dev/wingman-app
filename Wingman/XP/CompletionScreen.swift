//
//  CompletionScreen.swift
//  Wingman
//
//  The shared reward moment shown after a lesson, a scenario, or daily
//  practice.
//
//  DESIGN NOTES (the reasoning, so the next edit does not undo it)
//
//  The award is itemised, then summed. Line items name what earned each part
//  ("Completed", "3 correct", "All correct") and the green figure counts up as
//  though adding them together. Learning apps itemise because the breakdown
//  teaches the scoring; the restraint is in presenting it as a statement rather
//  than a celebration.
//
//  Items are grey and small so they read as one texture block, not three
//  elements competing with the sum. Awards with a single component fall through
//  to the figure alone — one line item above a figure saying the same number is
//  silly.
//
//  The lifetime total was deliberately cut from this screen. With line items
//  above and a level bar below it was a third way of saying "where you stand",
//  and the weakest of the three.
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
/// Itemised, the sequence lands at ~1.54s (~1.84s on a level-up). A
/// single-component award lands at ~1.12s. All inside the 2s budget.
private enum T {
    static let markIn = 0.26
    static let titleAt = 0.12,  titleIn = 0.22
    static let detailAt = 0.98, detailIn = 0.22
    static let xpAt = 0.52
    static let deltaIn = 0.20
    /// Gap between itemised lines. Three taps at this spacing is a rhythm; any
    /// tighter and it becomes a ticker.
    static let itemStagger = 0.14, itemIn = 0.18
    static let roll = 0.60, rollMilestone = 0.90
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
    @State private var displayedAmount: Double = 0
    @State private var revealedItems = 0
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
                // Itemised only when the award actually has parts. A scenario,
                // an approach, or a lesson answered entirely wrong is a single
                // component, and one line item above a figure saying the same
                // number is silly — those fall through to the figure alone.
                if components.count > 1 {
                    VStack(spacing: 4) {
                        ForEach(Array(components.enumerated()), id: \.offset) { index, item in
                            HStack(spacing: 10) {
                                Text("+\(item.amount)")
                                    .font(.manropeMedium(size: 13))
                                    .monospacedDigit()
                                    .frame(width: 34, alignment: .trailing)
                                Text(item.label)
                                    .font(.manropeMedium(size: 13))
                                    .frame(width: 96, alignment: .leading)
                            }
                            // Grey and small on purpose. The items are the
                            // working, not the answer — they should read as one
                            // texture block rather than three elements
                            // competing with the sum below them.
                            .foregroundColor(.gray)
                            .opacity(revealedItems > index ? 1 : 0)
                        }
                    }
                    .padding(.bottom, 4)
                }

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    RollingAmount(value: displayedAmount)
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

                // The lifetime total that used to sit here is gone. With line
                // items above and a level bar below it was a third way of
                // saying "where you stand", and the weakest of the three.

                levelRow
                    .padding(.top, 6)
                    .opacity(showLevel ? 1 : 0)
            }
        }
    }

    private var components: [(amount: Int, label: String)] {
        award?.components ?? []
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

        let items = award.components
        let itemised = items.count > 1

        guard !reduceMotion else {
            revealedItems = items.count
            showXP = true
            showLevel = true
            displayedAmount = Double(award.amount)
            HapticManager.shared.tap()
            after(0.20) { settleHaptic() }
            return
        }

        // Line items first, one per beat. Three taps 140ms apart is a rhythm,
        // and it is one event per line rather than one per digit — the latter
        // is the slot machine this design refuses.
        var cursor = 0.0
        if itemised {
            for index in items.indices {
                after(cursor) {
                    withAnimation(.easeOut(duration: T.itemIn)) { revealedItems = index + 1 }
                    HapticManager.shared.tap()
                }
                cursor += T.itemStagger
            }
        }

        // Then the sum, counting up as though it is adding the lines together.
        after(cursor) {
            withAnimation(.easeOut(duration: T.deltaIn)) { showXP = true }
            if !itemised { HapticManager.shared.tap() }
            withAnimation(rollCurve(rollDuration)) {
                displayedAmount = Double(award.amount)
            }
        }

        after(cursor + T.levelDelay) {
            withAnimation(.easeInOut(duration: T.levelIn)) { showLevel = true }
        }

        // Scheduled rather than detected: animation-completion callbacks are
        // less reliable than the duration we just asked for.
        after(cursor + rollDuration) { settleHaptic() }
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
///
/// This rolls the award itself rather than the lifetime total, because the
/// lifetime total was cut from this screen. Coming straight after the line
/// items, a sum counting up reads as those items adding together, which is
/// exactly the statement metaphor the breakdown is going for.
private struct RollingAmount: View, Animatable {
    var value: Double

    var animatableData: Double {
        get { value }
        set { value = newValue }
    }

    var body: some View {
        Text("+\(Int(value.rounded()))")
            .font(.manropeSemiBold(size: 20))
            .monospacedDigit()
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

#Preview("Itemised — perfect 3-question lesson") {
    CompletionScreen(
        title: "Lesson complete.",
        award: XPStore.Award(source: .lesson, amount: 40, totalAfter: 335,
                             base: 20, fromCorrect: 15, bonus: 5, correctCount: 3),
        onContinue: {}
    )
}

#Preview("Single component — falls back to the figure") {
    CompletionScreen(
        title: "Scenario complete.",
        award: XPStore.Award(source: .scenario, amount: 50, totalAfter: 385,
                             base: 50, fromCorrect: 0, bonus: 0, correctCount: 0),
        onContinue: {}
    )
}

#Preview("Level up") {
    CompletionScreen(
        title: "Lesson complete.",
        award: XPStore.Award(source: .lesson, amount: 40, totalAfter: 260,
                             base: 20, fromCorrect: 15, bonus: 5, correctCount: 3),
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
