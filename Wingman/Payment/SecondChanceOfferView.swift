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

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        Image(systemName: "tag.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.wingmanBlack)
                            .padding(.top, 36)

                        Text("Wait — here's 50% off")
                            .font(.manropeSemiBold(size: 24))
                            .foregroundColor(.wingmanBlack)
                            .multilineTextAlignment(.center)

                        Text("A one-time offer, just for you. Get a full year of Wingman Pro at half price.")
                            .font(.manropeRegular(size: 16))
                            .foregroundColor(Color(hex: "6B7280"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)

                        if let _ = viewModel.package {
                            offerCard
                                .padding(.horizontal, 20)
                                .padding(.top, 8)

                            disclosureText
                                .padding(.horizontal, 24)
                                .padding(.top, 4)
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
                }

                footerLinks
            }
            .background(Color.white)
        }
        .dynamicTypeSize(...DynamicTypeSize.large)
        .overlay(alignment: .topTrailing) {
            Button {
                HapticManager.shared.lightImpact()
                Analytics.capture(Analytics.Event.recoveryOfferDismissed, dismissEventProperties())
                authManager.markSecondChanceOfferShown(outcome: "dismissed")
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16))
                    .foregroundColor(.wingmanBlack)
                    .frame(width: 44, height: 44, alignment: .center)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
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
            // Covers a successful Restore on this screen — purchase success
            // is handled explicitly in continueButton's action instead, since
            // that path also needs to fire recovery_offer_purchased with
            // package-specific properties before dismissing.
            if newValue {
                authManager.markSecondChanceOfferShown(outcome: "restored")
                onDismiss()
            }
        }
        .onAppear {
            viewModel.load()

            guard viewModel.package != nil else {
                // Defensive only — SubscriptionGateModifier already confirmed
                // the package resolves before presenting this sheet. Nothing
                // was actually shown, so don't burn the "shown once" flag.
                log("⚠️ SecondChanceOfferView: package unavailable on appear — dismissing")
                onDismiss()
                return
            }

            if !didLogViewed {
                didLogViewed = true
                appearedAt = Date()
                Analytics.capture(Analytics.Event.recoveryOfferViewed, [
                    "product_id": viewModel.productId,
                    "discounted_price": viewModel.discountedPriceString,
                    "renewal_price": viewModel.renewalPriceString
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
            badgeText: "50% OFF — One Time Only",
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
                let success = await viewModel.purchase()
                if success {
                    authManager.markSecondChanceOfferShown(outcome: "purchased")
                    onDismiss()
                }
            }
        } label: {
            HStack {
                if viewModel.isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                        .padding(.trailing, 8)
                }
                Text(viewModel.isPurchasing ? "Processing..." : "Get 50% Off")
                    .font(.manropeSemiBold(size: 16))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .foregroundColor(.white)
            .background(Color.wingmanBlack.opacity(viewModel.isPurchasing ? 0.7 : 1.0))
            .cornerRadius(5)
        }
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

            Spacer()

            Button {
                Task {
                    _ = await viewModel.openRestore()
                    // On success, the hasActiveSubscription onChange above
                    // handles dismiss + persistence. A failed/no-op restore
                    // just leaves the user on this screen — no error UI,
                    // matching this screen's low-friction, skippable nature.
                }
            } label: {
                Text("Restore")
                    .font(.manropeMedium(size: 12))
                    .foregroundColor(Color(hex: "6B7280"))
                    .underline()
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }

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
        }
        .padding(.horizontal, 60)
        .padding(.bottom, 8)
    }

    // MARK: - Helpers
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
