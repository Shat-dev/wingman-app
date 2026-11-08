//
//  OneTimeOfferView.swift
//  Wingman
//
//  The one-time offer: a discounted first year, shown once, as soon as the
//  user closes the onboarding paywall without subscribing (subscribers route
//  to MainTabView first). Closing it starts the walkthrough.
//
//  "Only once" is enforced, not just claimed: the offer is spent the moment
//  it appears (`AuthManager.markPostDemoOfferSeen`), so a force-quit doesn't
//  bring it back. The copy promises exactly that and nothing more — there is
//  no countdown, because there is no deadline beyond leaving this screen.
//

import SwiftUI
import RevenueCat

struct OneTimeOfferView: View {

    @StateObject private var viewModel = OneTimeOfferViewModel()
    @EnvironmentObject var authManager: AuthManager

    /// Called once, when the user leaves by any route (purchase, close,
    /// restore, or the offer turning out to be unavailable).
    let onFinish: () -> Void

    @State private var appearedAt: Date?
    @State private var didFinish = false
    @State private var safariLink: IdentifiableURL?
    /// The X fades in 3 s after the offer is ready, so the first look is at
    /// the discount rather than at the way out (40% of closes came within 2 s).
    @State private var isCloseRevealed = false

    /// Secondary text grey, shared with the paywall's disclosure and footer.
    private let secondary = Color(hex: "6B7280")

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            switch viewModel.state {
            case .loading:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .wingmanBlack))
            case .ready:
                // Short screens (SE: ~647pt usable) get a smaller image and number.
                GeometryReader { geo in
                    content(isCompact: geo.size.height < 700)
                }
            case .unavailable:
                Color.clear
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.large)
        .overlay(alignment: .topTrailing) {
            if viewModel.state == .ready && isCloseRevealed {
                Button {
                    HapticManager.shared.tap()
                    close()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16))
                        .foregroundColor(.wingmanBlack)
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ScalePressStyle())
                .padding(.trailing, 8)
                .accessibilityLabel("Close offer")
                .transition(.opacity)
            }
        }
        .alert(viewModel.alertKind.title, isPresented: $viewModel.showAlert) {
            Button("OK") { viewModel.dismissAlert() }
        } message: {
            Text(viewModel.error ?? "An error occurred")
        }
        .onChange(of: viewModel.showAlert) { showing in
            if showing { viewModel.alertKind.playHaptic() }
        }
        .sheet(item: $safariLink) { link in
            SafariView(url: link.url).ignoresSafeArea()
        }
        .onChange(of: viewModel.state) { state in
            switch state {
            case .ready:
                guard appearedAt == nil else { return }
                appearedAt = Date()
                authManager.markPostDemoOfferSeen()
                ReviewPromptManager.shared.noteFriction(source: "one_time_offer")
                viewModel.reportViewed()
                Task {
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    withAnimation(.easeIn(duration: 0.3)) { isCloseRevealed = true }
                }
            case .unavailable:
                finish()
            case .loading:
                break
            }
        }
        // An entitlement arriving from elsewhere (a restore, a renewal synced
        // from another device) makes the offer moot.
        .onChange(of: authManager.hasActiveSubscription) { subscribed in
            if subscribed { finish() }
        }
        .task { await viewModel.load() }
        .trackScreenView("OneTimeOffer")
    }

    // MARK: - Content
    //
    // One idea per screen: this is a one-time price, and here it is. The
    // personalised ticks, subtitle and price card were cut (Nov 2026) — 40%
    // of viewers closed it within 2 s, so the discount has to be readable at a
    // glance. Built from the paywall's parts (white, `wingmanBlack`, Manrope,
    // 5pt corners) so it reads as the same app making a better offer.
    //
    // Every figure comes from StoreKit via the view model: the percentage is
    // computed from this storefront's two real prices, and the lengths
    // ("first year", "/year") from the product's intro and billing periods.

    private func content(isCompact: Bool) -> some View {
        VStack(spacing: 0) {
            // The landing screen's "what if" image, so the offer picks up
            // the thread from the first screen they saw.
            Image("landing_what_if")
                .resizable()
                .scaledToFit()
                .frame(maxHeight: isCompact ? 110 : 210)
                .padding(.horizontal, 8)
                .padding(.top, isCompact ? 36 : 52)
                .accessibilityHidden(true)

            // The question the image asks; the number below answers it.
            Text("Can you put a price on connection?")
                .font(.manropeBold(size: isCompact ? 22 : 26, relativeTo: .title))
                .foregroundColor(.wingmanBlack)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.top, isCompact ? 8 : 12)

            Spacer(minLength: isCompact ? 12 : 28)

            Text("ONE-TIME OFFER")
                .font(.manropeSemiBold(size: 12))
                .tracking(1.2)
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.wingmanBlack)
                .cornerRadius(6)
                .padding(.bottom, isCompact ? 8 : 4)

            hero(isCompact: isCompact)

            Spacer(minLength: 16)

            onceNotice
                .padding(.horizontal, 20)

            claimButton
                .padding(.horizontal, 20)
                .padding(.top, 12)

            Text("\(viewModel.introPriceString) billed today for your first \(viewModel.introDurationPhrase), then \(viewModel.fullPriceString)/\(viewModel.renewalPeriodPhrase). Cancel anytime in App Store settings.")
                .font(.manropeMedium(size: 12))
                .foregroundColor(secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)
                .padding(.top, 10)

            footerLinks
                .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
    }

    /// The discount as the whole screen. With no trustworthy percentage
    /// (`savingsPercent` nil) the price itself takes the big slot instead —
    /// never a guessed number.
    private func hero(isCompact: Bool) -> some View {
        VStack(spacing: 0) {
            Group {
                if let percent = viewModel.savingsPercent {
                    Text("\(percent)%")
                } else {
                    Text(viewModel.introPriceString)
                }
            }
            .font(.manropeBold(size: isCompact ? 64 : 88, relativeTo: .largeTitle))
            .foregroundColor(.wingmanBlack)
            .minimumScaleFactor(0.5)
            .lineLimit(1)

            Text(viewModel.savingsPercent != nil
                 ? "off your first \(viewModel.introDurationPhrase)"
                 : "for your first \(viewModel.introDurationPhrase)")
                .font(.manropeSemiBold(size: isCompact ? 22 : 26, relativeTo: .title))
                .foregroundColor(.wingmanBlack)
                .padding(.top, 2)

            HStack(spacing: 8) {
                Text(viewModel.fullPriceString)
                    .strikethrough(true, color: secondary)
                    .foregroundColor(secondary)
                Text(viewModel.introPriceString)
                    .foregroundColor(.wingmanBlack)
            }
            .font(.manropeSemiBold(size: 18))
            .padding(.top, isCompact ? 10 : 16)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        .accessibilityElement(children: .combine)
    }

    private var onceNotice: some View {
        HStack(spacing: 8) {
            Image(systemName: "eye.slash")
                .font(.system(size: 13, weight: .medium))
            Text("Close this and it\u{2019}s gone for good")
                .font(.manropeMedium(size: 14))
        }
        .foregroundColor(.wingmanBlack)
        .frame(maxWidth: .infinity)
    }

    private var claimButton: some View {
        Button {
            HapticManager.shared.tapStrong()
            authManager.markPurchaseStartedBeforeWalkthrough()
            Task {
                if await viewModel.purchase() {
                    HapticManager.shared.success()
                    finish()
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
                Text(viewModel.isPurchasing
                     ? "Processing..."
                     : viewModel.savingsPercent.map { "Claim \($0)% off" } ?? "Claim my discount")
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
    }

    /// Matches the paywall's footer: underlined, spread between 60pt insets.
    private var footerLinks: some View {
        HStack(spacing: 0) {
            footerLink("Privacy") { open(Constants.PRIVACY_POLICY_URL) }
            Spacer()
            footerLink("Restore") {
                Task {
                    if await viewModel.restore() { finish() }
                }
            }
            Spacer()
            footerLink("Terms") { open(Constants.TERMS_CONDITIONS_URL) }
        }
        .padding(.horizontal, 60)
    }

    private func footerLink(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.manropeMedium(size: 12))
                .foregroundColor(secondary)
                .underline()
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(ScalePressStyle())
        .disabled(viewModel.isPurchasing)
    }

    // MARK: - Exits

    private func open(_ urlString: String) {
        if let url = URL(string: urlString) { safariLink = IdentifiableURL(url: url) }
    }

    private func close() {
        guard !didFinish else { return }
        viewModel.reportDismissed(timeOnScreen: appearedAt.map { Date().timeIntervalSince($0) })
        finish()
    }

    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        onFinish()
    }
}
