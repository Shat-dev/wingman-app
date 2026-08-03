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

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.wingmanBlack)
                            .padding(.top, 36)

                        Text("Wait — here's \(discountPhrase)")
                            .font(.manropeSemiBold(size: 24))
                            .foregroundColor(.wingmanBlack)
                            .multilineTextAlignment(.center)

                        Text("A one-time offer, just for you. Get a full year of Wingman Pro at \(discountPhrase).")
                            .font(.manropeRegular(size: 16))
                            .foregroundColor(Color(hex: "6B7280"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        if let _ = viewModel.package {
                            offerCard
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                        } else {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .wingmanBlack))
                                .padding(.top, 40)
                        }
                    }
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
            .background(Color.white)
        }
        .dynamicTypeSize(...DynamicTypeSize.large)
        .overlay(alignment: .topTrailing) {
            Button {
                guard !didFinish else { return }
                HapticManager.shared.lightImpact()
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
        .alert("Error", isPresented: $viewModel.showAlert) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "An error occurred")
        }
        .sheet(item: $safariLink) { link in
            SafariView(url: link.url)
                .ignoresSafeArea()
        }
        .onChange(of: viewModel.showAlert) { showing in
            if showing { HapticManager.shared.error() }
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
        .postHogScreenView("SecondChanceOffer")
    }

    // MARK: - Offer Card
    private var offerCard: some View {
        PlanRow(
            title: "Yearly Plan",
            price: "\(viewModel.discountedPriceString) for your first year",
            weekly: viewModel.renewalPriceString,
            weeklySubtitle: "per year after",
            isSelected: true,
            badgeText: viewModel.savingsPercent.map { "\($0)% OFF — One Time Only" }
                ?? "ONE TIME ONLY",
            onSelect: {}
        )
        .allowsHitTesting(false) // single option, nothing to pick
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
            HapticManager.shared.mediumImpact()
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
        onDismiss()
    }

    private func dismissEventProperties() -> [String: Any] {
        var properties: [String: Any] = ["product_id": viewModel.productId]
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
