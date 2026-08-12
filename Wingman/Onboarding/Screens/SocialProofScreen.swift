//
//  SocialProofScreen.swift
//  Wingman
//
//  The last onboarding screen: stars, a "you're not the only one" headline,
//  and testimonial cards. Sits between the loading screen and whatever the
//  router shows next (the commitment pact, or the paywall when the pact flag
//  is off), so it is the final beat before the user is asked for money.
//
//  Descended from the deleted `RatingPromptView`, which occupied this same
//  slot and used this same layout. That screen fired StoreKit's
//  `requestReview()` on appear and App Review rejected build 1.07 (27) under
//  guideline 5.6.3 for asking during onboarding. The layout was never the
//  problem — the ask was. This screen therefore keeps the cards and drops the
//  ask entirely: **no StoreKit import, no `requestReview`, no rating UI of any
//  kind belongs in this file or anywhere else in the first-launch path.**
//  A rating ask can only live behind a real engagement gate (several sessions
//  across several days, plus completed content).
//
//  For the same reason the copy makes no countable claim — no user counts, no
//  download numbers, no ratings average. Nothing here can go stale or need
//  substantiating.
//

import SwiftUI

/// Copy for the social-proof screen, split from the view so wording can be
/// swapped or A/B'd without touching layout — the same arrangement
/// `GrowthProjectionContent` uses for the projection screen.
struct SocialProofContent {
    let headline: String
    let subtitle: String?
    /// Caption under the cards. Optional so the cards can stand alone.
    let footnote: String?
    let testimonials: [String]

    static let `default` = SocialProofContent(
        headline: "Join the men taking action",
        subtitle: "You're not the only one who's been stuck here.",
        footnote: "Things Wingman users have said",
        // Carried over verbatim from the screen this replaces.
        testimonials: [
            "I used to freeze up walking past a girl. After 3 weeks I had my first real conversation with a stranger. That was the win.",
            "I've read every book on this — none of them made me actually do anything. The daily structure changed that.",
            "No corny lines. Just calm, practical stuff about being present. My social anxiety is half what it was.",
            "I stopped dreading social situations entirely. That's worth more than any date."
        ]
    )
}

struct SocialProofScreen: View {
    var content: SocialProofContent = .default
    let onContinue: () -> Void

    /// Cards fade and rise in sequence behind the header rather than all
    /// landing at once, so the eye is walked down the stack instead of being
    /// handed four paragraphs in one frame. Held as a count rather than a
    /// per-card flag so the staggered schedule is one loop.
    @State private var revealedCards = 0

    /// Set on first appear, for `time_on_screen_seconds` on the continue
    /// event — the same pattern PaywallView and CommitmentPactView use.
    @State private var appearedAt: Date?

    /// One-shot guard: `onAppear` can re-fire on view-tree churn, and
    /// re-running the reveal schedule would flicker cards that already landed.
    @State private var didStartReveal = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: UIScreen.isSmallPhone ? 14 : 24) {
                    header

                    VStack(spacing: UIScreen.isSmallPhone ? 10 : 14) {
                        ForEach(Array(content.testimonials.enumerated()), id: \.element) { index, quote in
                            TestimonialCard(text: quote)
                                .opacity(index < revealedCards ? 1 : 0)
                                .offset(y: index < revealedCards ? 0 : 10)
                        }
                    }

                    if let footnote = content.footnote {
                        Text(footnote)
                            .font(.manropeRegular(size: 13))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }
                .padding(.top, UIScreen.isSmallPhone ? 4 : 20)
                .padding(.bottom, UIScreen.isSmallPhone ? 8 : 20)
            }

            Button(action: {
                HapticManager.shared.tap()

                var properties: [String: Any] = [:]
                if let appearedAt {
                    properties["time_on_screen_seconds"] = Analytics.elapsedSeconds(since: appearedAt)
                }
                Analytics.capture(Analytics.Event.socialProofContinued, properties)

                onContinue()
            }) {
                Text("Continue")
                    .font(.manropeSemiBold(size: 17))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.wingmanBlack)
                    .foregroundColor(.wingmanWhiteFF)
                    .cornerRadius(5)
            }
            .buttonStyle(ScalePressStyle())
            .contentShape(Rectangle())
        }
        .padding(.horizontal, UIScreen.isSmallPhone ? 20 : 24)
        .padding(.bottom, UIScreen.isSmallPhone ? 10 : 16)
        .onAppear {
            guard !didStartReveal else { return }
            didStartReveal = true
            appearedAt = Date()

            for index in content.testimonials.indices {
                withAnimation(.easeOut(duration: 0.35).delay(0.12 + Double(index) * 0.09)) {
                    revealedCards = index + 1
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: UIScreen.isSmallPhone ? 8 : 12) {
            // Tinted via `.renderingMode(.template)` so the imported PNG
            // renders in `wingmanBlack` whatever colour it was authored in.
            Image("stars")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundColor(.wingmanBlack)
                .frame(height: UIScreen.isSmallPhone ? 28 : 34)
                .padding(.horizontal, 56)

            Text(content.headline)
                .font(.manropeSemiBold(size: UIScreen.isSmallPhone ? 24 : 30))
                .foregroundColor(.wingmanBlack)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let subtitle = content.subtitle {
                Text(subtitle)
                    .font(.manropeRegular(size: UIScreen.isSmallPhone ? 14 : 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - Testimonial Card

/// White card with italic black text, flanked by laurel decorations. Matches
/// the onboarding aesthetic — subtle `wingmanBlack` stroke plus a soft shadow,
/// the same pattern `OptionButton` uses for question rows.
private struct TestimonialCard: View {
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            // Rendered natively, with no `.renderingMode(.template)` tint —
            // tinting flattens the laurel's internal detail (leaf shapes,
            // midribs) into a solid silhouette that reads as a chunky
            // parenthesis. The PNGs are already black-on-transparent, so they
            // sit correctly on the white card untouched.
            Image("left_leaves")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: UIScreen.isSmallPhone ? 36 : 44)

            Text("\u{201C}\(text)\u{201D}")
                .font(.manropeRegular(size: UIScreen.isSmallPhone ? 12 : 13))
                .italic()
                .foregroundColor(.wingmanBlack)
                .lineSpacing(UIScreen.isSmallPhone ? 2 : 3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Image("right_leaves")
                .resizable()
                .scaledToFit()
                .frame(width: 22, height: UIScreen.isSmallPhone ? 36 : 44)
        }
        .padding(.vertical, UIScreen.isSmallPhone ? 12 : 18)
        .padding(.horizontal, UIScreen.isSmallPhone ? 12 : 16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.wingmanBlack.opacity(0.15), lineWidth: 1)
        )
        .cornerRadius(10)
        .shadow(color: Color.wingmanBlack.opacity(0.06), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    SocialProofScreen(onContinue: {})
        .background(Color.white)
}
