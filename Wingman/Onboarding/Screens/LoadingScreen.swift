//
//  LoadingScreen.swift
//  Wingman
//
//  The final onboarding screen: an "optimizing your experience" sequence of
//  three step rows that fill one at a time, tick, then lock in with a
//  checkmark, before firing `onComplete`.
//
//  The progress is theatre, deliberately. Nothing here is wired to real work
//  — the durations are fixed constants and the whole run is ~6.2s every time
//  (`stepCount * (stepDuration + gapBetweenSteps) + finalDwell`) — because the
//  point is a predictable, satisfying rhythm rather than an honest read on a
//  network call. If you ever want the bars to reflect real progress, that's a
//  different screen; don't retrofit it onto this one.
//
//  Also stamps `onboarding_completed` in Supabase user_metadata for
//  authenticated users on appear (anonymous users have their state synced only
//  at signup) — unchanged from the version that showed animated dots.
//

import SwiftUI
import Supabase
import Auth

struct LoadingScreen: View {
    let step: OnboardingStep
    let onComplete: () -> Void

    @EnvironmentObject var authManager: AuthManager

    // MARK: - Copy

    private static let stepLabels = [
        "Analyzing your answers",
        "Building your practice plan",
        "Personalizing your lessons"
    ]

    /// Static line under the steps. Comes from the flow when the step supplies
    /// a subtitle, so the copy stays in `OnboardingFlow` with everything else.
    private var quote: String {
        step.subtitle ?? "Confidence is a skill. Skills are built."
    }

    // MARK: - Choreography (fixed, not data-driven)

    /// How long one bar takes to fill, linearly.
    private let stepDuration: TimeInterval = 1.8
    /// Beat between a step locking in and the next bar starting. Keeps the
    /// success haptic from colliding with the resumption of the tick pattern.
    private let gapBetweenSteps: TimeInterval = 0.1
    /// Beat after the last checkmark, so the user actually sees all three
    /// filled before the flow moves on.
    private let finalDwell: TimeInterval = 0.5
    /// Cadence of the continuous selection ticks underneath everything.
    private let tickInterval: TimeInterval = 0.2
    /// Curve the checkmark + label emphasis lock in on, as one unit.
    private let lockInDuration: TimeInterval = 0.3

    // MARK: - State

    @State private var stepProgress: [Double] = Array(
        repeating: 0, count: LoadingScreen.stepLabels.count
    )
    @State private var stepComplete: [Bool] = Array(
        repeating: false, count: LoadingScreen.stepLabels.count
    )

    /// The tick loop. Invalidated when the sequence finishes *and* on
    /// disappear, so it can never outlive the screen.
    @State private var tickTimer: Timer?

    /// `onAppear` can run more than once for the same screen (re-mount during
    /// a transition, for one). The sequence and the Supabase write are both
    /// one-shot, so they're gated on this rather than on `onAppear` alone.
    @State private var hasStarted = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Text(step.title)
                .font(.manropeSemiBold(size: 24))
                .foregroundColor(.wingmanBlack)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            VStack(spacing: 24) {
                ForEach(Self.stepLabels.indices, id: \.self) { index in
                    stepRow(index)
                }
            }
            .padding(.horizontal, 32)
            .padding(.top, 40)

            Text(quote)
                .font(.manropeRegular(size: 14))
                .foregroundColor(.wingmanBlack.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 44)
                .padding(.top, 36)

            Spacer()
        }
        .onAppear(perform: start)
        .onDisappear(perform: stopTickLoop)
    }

    // MARK: - Step row

    private func stepRow(_ index: Int) -> some View {
        let isComplete = stepComplete[index]

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Text(Self.stepLabels[index])
                    .font(isComplete ? .manropeSemiBold(size: 16) : .manropeRegular(size: 16))
                    .foregroundColor(.wingmanBlack.opacity(isComplete ? 1.0 : 0.55))

                Spacer(minLength: 8)

                // Outline while pending, filled once locked in. Both states
                // are the same glyph size, so the row height never shifts
                // mid-sequence.
                Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isComplete ? .customGreen : .wingmanBlack.opacity(0.25))
            }

            // GeometryReader so the fill is a fraction of the real row width
            // rather than a hardcoded number — the rows are inset from the
            // screen edges and that inset shouldn't have to be duplicated here.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)

                    Capsule()
                        .fill(Color.wingmanBlack)
                        .frame(
                            width: geo.size.width * max(0, min(1, stepProgress[index])),
                            height: 6
                        )
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Sequence

    private func start() {
        guard !hasStarted else { return }
        hasStarted = true

        // Save the name to Supabase whenever there is a user row to save it
        // against — guests included. Keyed on `hasSession` rather than the
        // legacy anonymous flag, which is still true for guests and would
        // otherwise drop their name on the floor.
        if authManager.hasSession {
            saveUserName()
        }

        startTickLoop()
        runStep(0)
    }

    /// Runs step `index` and chains the next one from its completion.
    ///
    /// Strictly one at a time: nothing starts until the previous bar has
    /// finished filling, so the sequence reads as a queue being worked
    /// through rather than three things loading at once.
    private func runStep(_ index: Int) {
        guard index < Self.stepLabels.count else {
            finish()
            return
        }

        // Linear, not eased. An easing curve reads as a real indeterminate
        // loader creeping toward an unknown end; a steady mechanical fill is
        // the point.
        withAnimation(.linear(duration: stepDuration)) {
            stepProgress[index] = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration) {
            // Checkmark fill and label emphasis ride the same curve, so the
            // row locks in as one unit...
            withAnimation(.easeInOut(duration: lockInDuration)) {
                stepComplete[index] = true
            }

            // ...and the success thump lands with the tick, not after it.
            // That simultaneity is what makes it feel like a confirmation
            // instead of a coincidence.
            HapticManager.shared.success()

            DispatchQueue.main.asyncAfter(deadline: .now() + gapBetweenSteps) {
                runStep(index + 1)
            }
        }
    }

    private func finish() {
        stopTickLoop()

        DispatchQueue.main.asyncAfter(deadline: .now() + finalDwell) {
            log("✅ Finished all questions")
            onComplete()
        }
    }

    // MARK: - Tick loop
    //
    // A continuous fine-grained texture — a dial spinning under the thumb —
    // that runs unbroken from appear to the last checkmark. It does not pause
    // or restart between steps: the coarse success thumps are the punctuation,
    // and this is the surface they punctuate.
    //
    // Selection feedback rather than an impact on purpose. At five fires a
    // second over ~6 seconds an impact tick would fatigue; the picker-detent
    // one stays comfortable.

    private func startTickLoop() {
        stopTickLoop()

        let timer = Timer(timeInterval: tickInterval, repeats: true) { _ in
            // Timer callbacks are not actor-isolated, so hop before touching
            // the main-actor haptic manager.
            Task { @MainActor in
                HapticManager.shared.selection()
            }
        }
        // `.common` so the cadence survives any tracking run-loop mode the
        // flow's swipe-back gesture puts the app into.
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }

    private func stopTickLoop() {
        tickTimer?.invalidate()
        tickTimer = nil
    }

    // MARK: - Save to Supabase (Auth User Metadata)
    private func saveUserName() {
        // Name is no longer collected during onboarding (SIWA/Google already
        // supply it; email-signup users can set one from Profile). This call
        // only stamps onboarding_completed — it must not write display_name,
        // because doing so would overwrite the SIWA/Google-provided name
        // already stored in user_metadata.
        let updatedAt = ISO8601DateFormatter().string(from: Date())

        log("📤 Marking onboarding complete in Supabase")

        Task {
            do {
                let client = SupabaseManager.shared.client

                try await client.auth.update(
                    user: UserAttributes(
                        data: [
                            "onboarding_completed": AnyJSON.bool(true),
                            "updated_at": AnyJSON.string(updatedAt)
                        ]
                    )
                )

                log("✅ User metadata saved successfully")

            } catch {
                log("❌ Error saving user metadata:", error.localizedDescription)
            }
        }
    }
}

#Preview {
    // Runs the real sequence — bars, checkmarks and haptics all fire — then
    // calls an `onComplete` with no flow to advance into. The Supabase write
    // fails silently in previews (no session).
    LoadingScreen(
        step: extendedOnboardingSteps.last!,
        onComplete: {}
    )
    .environmentObject(AuthManager())
}
