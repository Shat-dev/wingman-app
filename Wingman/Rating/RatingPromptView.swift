//
//  RatingPromptView.swift
//  Wingman
//
//  Shown once, between the end of onboarding ("Personalizing an experience
//  just for you...") and the paywall. Serves as social proof + a gentle
//  ask for a rating before the user hits the pricing screen.
//
//  Routing: `WingmanApp` gates presentation on
//  `!hasCompletedPaywallFlow && !hasSeenRatingPrompt`, so once the user
//  taps Continue (which calls `completeRatingPrompt()`) they never route
//  back here — and existing paying users with `hasCompletedPaywallFlow == true`
//  never see it at all (no regression for returning subscribers).
//
//  Visual treatment flows with the rest of Wingman's onboarding: white
//  background, `wingmanBlack` text and laurels, testimonial cards rendered
//  as white cards with a subtle `wingmanBlack` stroke + soft shadow (the
//  same pattern used by `OptionButton` elsewhere in onboarding). Stars and
//  laurels are tinted via `.renderingMode(.template)` so the imported PNGs
//  render in `wingmanBlack` regardless of their source colour. Only the
//  Continue button retains the dark fill — consistent with the primary-CTA
//  pattern across the rest of the onboarding flow.
//

import SwiftUI
import StoreKit  // for @Environment(\.requestReview) — RequestReviewAction's
                 // callAsFunction lives in StoreKit and this project has
                 // Swift's `MemberImportVisibility` upcoming feature enabled,
                 // so we need an explicit import (not just SwiftUI's re-export).

struct RatingPromptView: View {
    @EnvironmentObject var authManager: AuthManager

    // Apple's native review request (iOS 16+). Calling this triggers the
    // system rating popup (rate-limited by iOS to 3× per 365 days per app).
    @Environment(\.requestReview) private var requestReview

    // One-shot guard: prevents `onAppear` re-firing (which can happen on
    // SwiftUI view-tree churn) from re-requesting the review mid-session.
    @State private var hasRequestedReview = false

    // Continue is disabled for ~500ms after the screen appears so the
    // system popup has time to fire (at 300ms) and become visible (~400–500ms)
    // before the user can tap past it. See `.onAppear` below.
    @State private var isContinueEnabled = false

    // Cancellable handle for the scheduled `requestReview()` call. If the
    // user somehow advances past this screen before 300ms elapses (rare —
    // requires backgrounding the app or an unexpected routing race),
    // `.onDisappear` cancels this so the popup doesn't land on the paywall.
    @State private var reviewWorkItem: DispatchWorkItem?

    // Testimonials from the wireframe, verbatim.
    private let testimonials: [String] = [
        "I used to freeze up walking past a girl. After 3 weeks I had my first real conversation with a stranger. That was the win.",
        "I've read every book on this — none of them made me actually do anything. The daily structure changed that.",
        "No corny lines. Just calm, practical stuff about being present. My social anxiety is half what it was.",
        "I stopped dreading social situations entirely. That's worth more than any date."
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {

                    // MARK: - Header: 5 stars + title + subtitle
                    VStack(spacing: 12) {
                        Image("stars")
                            .resizable()
                            .renderingMode(.template)
                            .scaledToFit()
                            .foregroundColor(.wingmanBlack)
                            .frame(height: 36)
                            .padding(.horizontal, 80)

                        Text("Give us a rating")
                            .font(.manropeSemiBold(size: 32))
                            .foregroundColor(.wingmanBlack)
                            .multilineTextAlignment(.center)

                        Text("Help us grow")
                            .font(.manropeRegular(size: 16))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    // MARK: - Testimonial cards
                    VStack(spacing: 14) {
                        ForEach(testimonials, id: \.self) { quote in
                            TestimonialCard(text: quote)
                        }
                    }
                    .padding(.horizontal, 20)

                    // MARK: - Footer caption
                    Text("Things that users have said")
                        .font(.manropeRegular(size: 13))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .padding(.bottom, 20)
            }

            // MARK: - Continue button pinned at bottom (matches paywall pattern)
            // Disabled for the first ~700ms after the screen appears so the
            // system rating popup (fired at 500ms, visible ~600–700ms) is
            // guaranteed to reach the user before they can advance.
            Button(action: {
                HapticManager.shared.mediumImpact()
                authManager.completeRatingPrompt()
            }) {
                Text("Continue")
                    .font(.manropeSemiBold(size: 16))
                    .foregroundColor(.wingmanWhiteFF)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.wingmanBlack)
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .disabled(!isContinueEnabled)
            .opacity(isContinueEnabled ? 1 : 0.5)
            .padding(.horizontal, 20)
            .padding(.bottom, 12)
        }
        .background(Color.white.ignoresSafeArea())
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            // Guard against `onAppear` re-entry (SwiftUI can re-fire this if
            // the parent view tree churns). Apple's own rate-limit (3/365d)
            // is a second line of defense.
            guard !hasRequestedReview else { return }
            hasRequestedReview = true

            // Schedule the popup for 500ms after render — gives the slide-in
            // transition time to settle and the user a beat to register the
            // screen's context ("Give us a rating") + read some of the
            // testimonials before the system modal overlays it.
            let item = DispatchWorkItem { [requestReview] in
                requestReview()
            }
            reviewWorkItem = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: item)

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    isContinueEnabled = true
                }
            }
        }
        .onDisappear {
            // If the view is dismissed before the 500ms popup fires (edge
            // cases: app backgrounded, unexpected routing race), cancel the
            // pending `requestReview()` so the system popup doesn't land
            // on the paywall (or whatever screen replaces this one).
            reviewWorkItem?.cancel()
            reviewWorkItem = nil
        }
    }
}

// MARK: - Testimonial Card
/// White card with black italic text, flanked by black laurel decorations.
/// Styled to match the rest of the onboarding aesthetic (white background,
/// subtle `wingmanBlack` stroke + soft shadow — same pattern as `OptionButton`).
/// Leaves are tinted via `.renderingMode(.template)` so the imported PNGs
/// render in `wingmanBlack` regardless of their source colour.
private struct TestimonialCard: View {
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Render the laurel PNGs natively — no `.renderingMode(.template)`
            // tint, which would flatten the illustration's internal detail
            // (leaf shapes, midribs, shading) to a solid black silhouette
            // that reads as a chunky "(" / ")" shape instead of a laurel.
            // The supplied PNGs are already black-on-transparent, so they
            // sit correctly on the white card without any tint applied.
            Image("left_leaves")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 44)

            Text("\u{201C}\(text)\u{201D}")
                .font(.manropeRegular(size: 13))
                .italic()
                .foregroundColor(.wingmanBlack)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Image("right_leaves")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: 44)
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 16)
        .background(Color.white)
        .overlay(
            // Subtle stroke — matches OptionButton's definition pattern in
            // onboarding, gives the card edges against the white page without
            // the heavy "tappable button" read of a full-opacity stroke.
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.wingmanBlack.opacity(0.15), lineWidth: 1)
        )
        .cornerRadius(10)
        .shadow(color: Color.wingmanBlack.opacity(0.06), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    RatingPromptView()
        .environmentObject(AuthManager())
}
