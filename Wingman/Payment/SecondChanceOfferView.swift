//
//  SecondChanceOfferView.swift
//  Wingman
//
//  One-time 50%-off-year-1 recovery offer, presented by
//  SubscriptionGateModifier immediately after a user dismisses the
//  feature-gated paywall without purchasing. Deliberately a separate,
//  minimal view rather than a mode of PaywallView — see
//  docs/second-chance-paywall-plan.md §4.3 for the rationale.
//
//  Always dismissible: this is an opt-in, skippable, one-time offer, never
//  a blocking gate.
//

import SwiftUI
import Combine
import RevenueCat
import PostHog

struct SecondChanceOfferView: View {

    @StateObject private var viewModel = SecondChanceOfferViewModel()
    @EnvironmentObject var authManager: AuthManager

    /// Closes the sheet. Persistence (`markSecondChanceOfferShown`) is
    /// handled inside this view, not by the caller — the "shown once, ever"
    /// guarantee must hold regardless of which call site presented this
    /// screen.
    let onDismiss: () -> Void

    /// Called when this view has already captured a dismissal event for the
    /// current presentation, so the presenter's swipe-away fallback doesn't
    /// double-count it. Same contract as `PaywallView.onDismissReported`.
    ///
    /// Defaulted so call sites that don't run the fallback (previews) are
    /// unaffected.
    var onOutcomeReported: () -> Void = {}

    @State private var didLogViewed = false
    @State private var appearedAt: Date?
    @State private var safariLink: IdentifiableURL?

    /// Set by `finish(outcome:)`. Four paths can resolve this screen and two of
    /// them fire for the same event — see `finish(outcome:)`.
    @State private var didFinish = false

    /// True while an explicit purchase or restore is in flight. Keeps the
    /// `hasActiveSubscription` safety net below from claiming an outcome that
    /// belongs to one of those paths.
    @State private var isResolving = false

    /// Live countdown on the discount window opened when this screen appeared.
    /// Seeded with the full window so the first frame never shows a placeholder.
    @State private var remaining: TimeInterval = AuthManager.secondChanceDiscountWindow

    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Hero sizing
    //
    // A share of the modal's height, clamped at both ends. This replaced a
    // measure-the-content-and-take-the-leftover scheme (the approach
    // `PaywallView` uses for its carousel): the preference values never
    // arrived here, so the hero silently sat on its floor at every screen size
    // while ~90pt of space went unused above the CTA. A rule that always
    // produces the number beats a smarter one that quietly falls back.
    //
    // The clamps are what make it safe across the range rather than the
    // fraction: the ceiling stops a 6.9" screen turning the modal into a poster,
    // and the floor stops an SE shrinking the two figures to the point where
    // they no longer read as two people.

    private static let heroHeightFraction: CGFloat = 0.185
    private static let heroMinHeight: CGFloat = 118
    private static let heroMaxHeight: CGFloat = 168

    /// - Parameter modalHeight: the sheet's own height, from the enclosing
    ///   `GeometryReader` — not the screen's. Sheets are inset from the top and
    ///   sit above the home indicator, and sizing off the screen would overstate
    ///   the space by roughly 100pt on every device.
    private func heroHeight(in modalHeight: CGFloat) -> CGFloat {
        min(Self.heroMaxHeight, max(Self.heroMinHeight, modalHeight * Self.heroHeightFraction))
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroImage(height: heroHeight(in: proxy.size.height))
                            .padding(.top, 4)
                            .padding(.horizontal, 24)

                        // The offer itself, grouped: headline through closing
                        // line. Kept as one block so the paddings that hold it
                        // together are read and tuned together.
                        VStack(spacing: 0) {
                            // Two lines, enforced rather than hoped for. At
                            // three it pushed the price card under the CTA on
                            // every phone; `minimumScaleFactor` absorbs the
                            // difference on narrow screens instead of letting
                            // the layout below pay for it.
                            Text("How many more times do you want to walk away wondering ‘what if’?")
                                .font(.manropeSemiBold(size: 20))
                                .foregroundColor(.wingmanBlack)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.75)
                                .padding(.top, 24)
                                .padding(.horizontal, 20)

                            Text("Every opportunity you let pass becomes one you replay.")
                                .font(.manropeRegular(size: 15))
                                .foregroundColor(Color(hex: "6B7280"))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 8)
                                .padding(.horizontal, 32)

                            if let _ = viewModel.package {
                                offerCard
                                    .padding(.horizontal, 20)
                                    .padding(.top, 20)

                                countdownLine
                                    .padding(.horizontal, 32)
                                    .padding(.top, 12)

                                identityLine
                                    .padding(.horizontal, 32)
                                    .padding(.top, 16)
                                    .padding(.bottom, 8)
                            } else {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .wingmanBlack))
                                    .padding(.top, 40)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: .infinity)

                if viewModel.package != nil {
                    continueButton

                    // Pinned below the CTA, never inside the ScrollView above,
                    // matching PaywallView. This is the longest and most
                    // legally load-bearing disclosure in the app — discounted
                    // first year AND a different renewal price (Guideline
                    // 3.1.2) — so it is the one that could least afford to end
                    // up below the fold. This screen has room to spare today;
                    // pinning is preventive, since the copy interpolates two
                    // localized price strings and can grow.
                    disclosureText
                        .padding(.horizontal, 24)
                        .padding(.bottom, 4)
                }

                footerLinks
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(Color.white)
        }
        .dynamicTypeSize(...DynamicTypeSize.large)
        .overlay(alignment: .topTrailing) {
            Button {
                guard !didFinish else { return }
                HapticManager.shared.tap()
                Analytics.capture(Analytics.Event.recoveryOfferDismissed, dismissEventProperties())
                finish(outcome: "dismissed")
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16))
                    .foregroundColor(.wingmanBlack)
                    .frame(width: 44, height: 44, alignment: .center)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScalePressStyle())
            .padding(.trailing, 6)
            .accessibilityLabel("Close offer")
        }
        .alert(viewModel.alertKind.title, isPresented: $viewModel.showAlert) {
            Button("OK") { viewModel.dismissAlert() }
        } message: {
            Text(viewModel.error ?? "An error occurred")
        }
        .sheet(item: $safariLink) { link in
            SafariView(url: link.url)
                .ignoresSafeArea()
        }
        .onChange(of: viewModel.showAlert) { showing in
            if showing { viewModel.alertKind.playHaptic() }
        }
        .onReceive(ticker) { _ in
            // Read off the absolute deadline rather than decremented, so time
            // spent backgrounded lands on the right number — or straight on
            // expiry — at the first tick after resume.
            guard let deadline = authManager.secondChanceDiscountDeadline else { return }
            let left = deadline.timeIntervalSinceNow
            remaining = max(0, left)

            guard left <= 0, !didFinish else { return }
            log("🎁 SecondChanceOfferView: discount window expired while open — closing")
            Analytics.capture(Analytics.Event.recoveryOfferWindowExpired, [
                "source": "recovery_offer",
                "product_id": viewModel.productId
            ])
            // Closing is the point. Leaving a "Get 50% off" button live under a
            // clock reading 0:00 would make the deadline decorative, and this
            // screen's whole claim to the countdown is that it is not.
            finish(outcome: "expired")
        }
        .onChange(of: authManager.hasActiveSubscription) { newValue in
            // Safety net ONLY. Purchase and Restore each resolve themselves at
            // their own call site now, because both need to distinguish their
            // outcome and both used to lose the race to this handler (see
            // `finish(outcome:)`).
            //
            // What is left for this to catch is entitlement arriving from
            // somewhere other than this screen while it happens to be open: the
            // 5-minute poll, the foreground refresh, or a RevenueCat delegate
            // push (a purchase on another device, a Family Sharing grant). Rare,
            // but leaving the user staring at a purchase screen they no longer
            // need would be worse than the handler costs.
            guard newValue, !isResolving else { return }
            log("🎁 SecondChanceOfferView: entitlement arrived from outside this screen")
            finish(outcome: "subscribed_externally")
        }
        .onAppear {
            // Same reasoning as PaywallView's call: this screen is a price
            // ask, so it disqualifies the session from the rating prompt.
            // Noted before the defensive guard below, deliberately — a user
            // who reached a broken discount screen is the last person to put
            // a five-star prompt in front of.
            ReviewPromptManager.shared.noteFriction(source: "second_chance_offer")

            viewModel.load()

            guard viewModel.package != nil, viewModel.hasIntroductoryOffer else {
                // Defensive only — SubscriptionGateModifier already confirmed
                // both the package resolves AND that it carries the intro offer
                // this screen is pitching, before presenting this sheet.
                //
                // Kept as a second layer because the failure is silent and
                // expensive: without the offer, every price here renders blank
                // and the "Get 50% Off" button charges full price. Any future
                // call site that forgets the gate's checks fails closed here
                // instead.
                //
                // Nothing was actually shown, so don't burn the "shown once"
                // flag — bare `onDismiss()`, not `finish(outcome:)`.
                log("⚠️ SecondChanceOfferView: package or intro offer unavailable on appear — dismissing (package=\(viewModel.package != nil) introOffer=\(viewModel.hasIntroductoryOffer))")
                onDismiss()
                return
            }

            if !didLogViewed {
                didLogViewed = true
                appearedAt = Date()

                // Burn the "shown once, ever" flag HERE rather than in
                // `finish(outcome:)`.
                //
                // `finish` is only reachable from this view's own controls, but
                // the sheet can also be closed by swiping it down — SwiftUI
                // flips the presentation binding directly, so `finish` never
                // runs, `markSecondChanceOfferShown` never runs, and the offer
                // re-arms on the next feature-gate dismissal. Forever. In
                // production that produced four presentations to one user inside
                // sixty seconds. `didLogViewed` cannot catch it: it is `@State`,
                // so each presentation is a fresh view with a fresh guard.
                //
                // Marking on appear makes the guarantee structural — the offer
                // is spent at the moment it is actually on screen, so no exit
                // path can leak. This sits *after* the package/intro-offer
                // early return above, which deliberately dismisses without
                // burning the flag because nothing was shown in that case.
                //
                // `finish(outcome:)` still calls this with the real outcome,
                // which upgrades `second_chance_offer_outcome` in user_metadata
                // from "viewed" to "purchased"/"dismissed"/etc.
                authManager.markSecondChanceOfferShown(outcome: "viewed")

                Analytics.capture(Analytics.Event.recoveryOfferViewed, [
                    "product_id": viewModel.productId,
                    "discounted_price": viewModel.discountedPriceString,
                    "renewal_price": viewModel.renewalPriceString,
                    // Computed per storefront, so this is how you see whether
                    // Apple's price tiers actually deliver ~50% everywhere or
                    // drift in some territories. A spread here is expected and
                    // fine; a cluster far from 50 means the ASC intro price
                    // needs revisiting.
                    "savings_percent": viewModel.savingsPercent ?? -1
                ])
            }
        }
        .trackScreenView("SecondChanceOffer")
    }

    // MARK: - Hero
    //
    // The same illustration the practice scenarios use for the walk-away beat,
    // so the screen opens on a picture of the exact moment the headline names
    // rather than on a discount symbol.
    //
    // `scaledToFit` inside a fixed-height frame, never `scaledToFill` + clip:
    // the drawing's meaning is the *distance* between the two figures, and any
    // crop tight enough to fill the frame eats the gap or the second figure.
    // When the frame is narrower than it is tall (small phones, large text) the
    // image simply becomes width-limited and centres itself — still uncropped.
    private func heroImage(height: CGFloat) -> some View {
        Image("scenario_leave")
            .resizable()
            .scaledToFit()
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    // MARK: - Offer Card
    //
    // Deliberately NOT `PlanRow`. That component exists to let a user *choose*
    // between plans — it carries a radio button, which this screen had to
    // disable with `allowsHitTesting(false)` because there is nothing to pick.
    // A dead radio button on a one-option screen reads as a broken control.
    //
    // More importantly, PlanRow has nowhere to put the comparison. It shows a
    // price; this screen's entire job is to show a price *against another
    // price*. The struck-through original is the argument — without it, "50%
    // off" is a claim the user has to take on faith while looking at a number
    // that means nothing on its own.
    private var offerCard: some View {
        VStack(spacing: 0) {

            // Badge bar — same treatment as PlanRow's (white on wingmanBlack,
            // full-bleed across the card top) so this reads as the same family
            // of component even though it is a different one.
            if let percent = viewModel.savingsPercent {
                Text("Save \(percent)%, next 30 minutes only")
                    .font(.manropeMedium(size: 13))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .background(Color.wingmanBlack)
            }

            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    // Suppressed rather than rendered blank if the standard
                    // price is missing: a strikethrough against nothing turns
                    // the comparison into a bare number, which is worse than
                    // showing the discounted price alone.
                    if !viewModel.renewalPriceString.isEmpty {
                        Text(viewModel.renewalPriceString)
                            .font(.manropeMedium(size: 20))
                            .foregroundColor(Color(hex: "9CA3AF"))
                            .strikethrough(true, color: Color(hex: "9CA3AF"))
                    }

                    Text(viewModel.discountedPriceString)
                        .font(.manropeBold(size: 34))
                        .foregroundColor(.wingmanBlack)
                }
                .fixedSize(horizontal: false, vertical: true)

                Text("for your first year")
                    .font(.manropeMedium(size: 14))
                    .foregroundColor(Color(hex: "6B7280"))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.wingmanBlack, lineWidth: 1.5)
        )
    }

    // MARK: - Countdown
    //
    // Honest because it is enforced. `AuthManager.secondChanceDiscountWindow`
    // really does end: this screen closes itself at zero (below), and
    // `PaywallViewModel` stops serving the discounted package at the same
    // instant. Nothing here resets, and nothing survives the deadline it
    // states — which is the difference between this and the countdown the
    // original version of this screen deliberately refused to show.
    private var countdownLine: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock")
                .font(.system(size: 13, weight: .medium))

            Text("Offer ends in \(OfferCountdown.format(remaining))")
                .font(.manropeMedium(size: 15))
        }
        .foregroundColor(.wingmanBlack)
        .frame(maxWidth: .infinity)
        // One announcement, in minutes. A per-second VoiceOver update would
        // talk over everything else on the screen.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Offer ends in \(Int(remaining / 60)) minutes")
    }

    // MARK: - Identity Line
    //
    // The close, and the last thing read before the button. Sits below the card
    // rather than above it so the price is what the emotional line lands on
    // top of, not something the user still has to go looking for afterwards.
    //
    // Smaller than the headline on purpose: it echoes that question rather than
    // competing with it, and two 22pt lines bracketing the card would leave the
    // price as the quietest thing on a screen whose job is to show a price.
    //
    // This is also where the old "one-time offer, you won't see this again"
    // line used to sit. That claim is still made — and still true, since
    // `hasSeenSecondChanceOffer` is a once-ever per-user flag mirrored to
    // Supabase — but it now lives in the card's banner, which is where a user
    // scanning only the price will actually see it. Still no countdown timer:
    // nothing here expires with time, and a fake deadline is a Guideline 5.6
    // rejection waiting to happen.
    private var identityLine: some View {
        Text("Become the man who doesn’t walk away.")
            .font(.manropeSemiBold(size: 18))
            .foregroundColor(.wingmanBlack)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Disclosure (App Store Guideline 3.1.2 — exact pricing/renewal terms)
    private var disclosureText: some View {
        Text("Billed \(viewModel.discountedPriceString) today for your first year. Renews automatically at \(viewModel.renewalPriceString)/year after. Cancel anytime in App Store settings.")
            .font(.manropeMedium(size: 12))
            .foregroundColor(Color(hex: "6B7280"))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: - Continue Button
    private var continueButton: some View {
        Button {
            HapticManager.shared.tapStrong()
            Task {
                // Claimed BEFORE the first suspension point, so it is already
                // true by the time `purchase()` flips `hasActiveSubscription`.
                // Reading `viewModel.isPurchasing` instead would be racy —
                // SwiftUI can coalesce that flag's reset into the same update
                // that delivers the entitlement change.
                isResolving = true
                let success = await viewModel.purchase()
                if success {
                    finish(outcome: "purchased")
                }
                isResolving = false
            }
        } label: {
            HStack {
                if viewModel.isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                        .padding(.trailing, 8)
                }
                Text(viewModel.isPurchasing ? "Processing..." : "Get \(discountPhrase)")
                    .font(.manropeSemiBold(size: 16))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundColor(.white)
            .background(Color.wingmanBlack.opacity(viewModel.isPurchasing ? 0.7 : 1.0))
            .cornerRadius(5)
        }
        .buttonStyle(ScalePressStyle())
        .disabled(viewModel.isPurchasing)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    // MARK: - Footer Links
    private var footerLinks: some View {
        HStack(spacing: 0) {
            Button {
                if let url = URL(string: Constants.PRIVACY_POLICY_URL) {
                    safariLink = IdentifiableURL(url: url)
                }
            } label: {
                Text("Privacy")
                    .font(.manropeMedium(size: 12))
                    .foregroundColor(Color(hex: "6B7280"))
                    .underline()
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScalePressStyle())

            Spacer()

            Button {
                Task {
                    // Resolved here rather than through the onChange above, so
                    // the outcome is recorded as a restore even when the
                    // entitlement change is what SwiftUI notices first.
                    isResolving = true
                    let restored = await viewModel.openRestore()
                    if restored {
                        finish(outcome: "restored")
                    }
                    isResolving = false
                    // A failed/no-op restore just leaves the user on this
                    // screen — no error UI, matching this screen's
                    // low-friction, skippable nature.
                }
            } label: {
                Text("Restore")
                    .font(.manropeMedium(size: 12))
                    .foregroundColor(Color(hex: "6B7280"))
                    .underline()
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScalePressStyle())

            Spacer()

            Button {
                if let url = URL(string: Constants.TERMS_CONDITIONS_URL) {
                    safariLink = IdentifiableURL(url: url)
                }
            } label: {
                Text("Terms")
                    .font(.manropeMedium(size: 12))
                    .foregroundColor(Color(hex: "6B7280"))
                    .underline()
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScalePressStyle())
        }
        .padding(.horizontal, 60)
        .padding(.bottom, 8)
    }

    // MARK: - Helpers

    /// "50% off" for most storefronts — but read from this storefront's real
    /// prices, because Apple's price tiers do not land on exactly half the base
    /// price everywhere. See `SecondChanceOfferViewModel.savingsPercent`.
    ///
    /// The fallback deliberately makes **no numeric claim** rather than
    /// defaulting to "50%": a wrong percentage next to a correct price is worse
    /// than a vague one, and it is the exact thing Guideline 3.1.2 is checked
    /// against. Unreachable in practice — the screen is not presented without a
    /// resolvable introductory offer — but the fallback has to be honest, not
    /// convenient, or it stops being a fallback and starts being the bug.
    private var discountPhrase: String {
        viewModel.savingsPercent.map { "\($0)% off" } ?? "a one-time discount"
    }

    /// The single exit point: records the outcome and closes the sheet, exactly
    /// once.
    ///
    /// The guard is load-bearing, not defensive. A successful purchase flips
    /// `authManager.hasActiveSubscription` *synchronously inside*
    /// `viewModel.purchase()` — `handleCustomerInfoUpdate` posts on the calling
    /// thread (SubscriptionManager.swift:258) and AuthManager's observer is a
    /// plain `@objc` selector — and `purchase()` then suspends on
    /// `refreshSubscriptionStatus()`, which is exactly when SwiftUI delivers
    /// the `hasActiveSubscription` `onChange`. So the safety net used to run *before* the
    /// purchase closure it was written to defer to: the offer got marked twice
    /// with two different outcomes, racing two `user_metadata` writes, and
    /// `onDismiss()` was called twice.
    ///
    /// `isResolving` fixes the ordering (the right outcome wins the race);
    /// `didFinish` fixes the duplication (the loser is dropped rather than
    /// overwriting). Both are needed — neither alone is sufficient.
    private func finish(outcome: String) {
        guard !didFinish else {
            log("🎁 SecondChanceOfferView: finish(\(outcome)) ignored — already resolved")
            return
        }
        didFinish = true
        authManager.markSecondChanceOfferShown(outcome: outcome)

        // Tell the presenter this presentation was resolved in-view, so its
        // swipe-away fallback stays quiet. Every path that resolves this screen
        // funnels through here, which is why the signal lives at this one point
        // rather than next to each `Analytics.capture` above.
        onOutcomeReported()

        onDismiss()
    }

    private func dismissEventProperties() -> [String: Any] {
        var properties: [String: Any] = [
            "product_id": viewModel.productId,
            // Distinguishes this from the presenter's swipe fallback, which
            // reports the same event with `dismiss_method = "swipe"`. Without
            // it the two paths are indistinguishable in the same insight.
            "dismiss_method": "button"
        ]
        if let appearedAt {
            properties["time_on_screen_seconds"] = Analytics.elapsedSeconds(since: appearedAt)
        }
        return properties
    }
}

#Preview {
    SecondChanceOfferView(onDismiss: {})
        .environmentObject(AuthManager())
}
