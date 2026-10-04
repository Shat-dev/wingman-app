//
//  OneTimeOfferView.swift
//  Wingman
//
//  The one-time offer: 50% off the first year, shown once, as soon as the
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

    /// Read once per mount: the onboarding answers can't change while the
    /// offer is on screen.
    @State private var ticks = PaywallCopy.offerTicks

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
                // Short screens (SE: ~647pt usable) can't fit the illustration
                // and the full pitch above the pinned price block; the words
                // win, as on the main paywall.
                GeometryReader { geo in
                    content(isCompact: geo.size.height < 700)
                }
            case .unavailable:
                Color.clear
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.large)
        .overlay(alignment: .topTrailing) {
            if viewModel.state == .ready {
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
    // Built from the paywall's own parts — white ground, `wingmanBlack` type
    // and controls, Manrope, 5pt corners, the line illustrations and the
    // `check` glyph — so it reads as the same app making a better offer,
    // not a different screen bolted on.

    private func content(isCompact: Bool) -> some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    // The "what if" daydream from onboarding's regret stat.
                    if !isCompact {
                        Image("stat_regret")
                            .resizable()
                            .scaledToFit()
                            .frame(minHeight: 80, maxHeight: 120)
                            .padding(.top, 20)
                            .accessibilityHidden(true)
                    }

                    Text("ONE-TIME OFFER")
                        .font(.manropeSemiBold(size: 12))
                        .tracking(1.2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.wingmanBlack)
                        .cornerRadius(6)
                        .padding(.top, isCompact ? 8 : 16)

                    Text("Can you put a price on connection?")
                        .font(.manropeBold(size: 26, relativeTo: .title))
                        .foregroundColor(.wingmanBlack)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 14)
                        .padding(.horizontal, 24)

                    Text("How many more times do you want to walk away wondering \u{201C}what if\u{201D}?")
                        .font(.manropeRegular(size: 16))
                        .foregroundColor(secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 10)
                        .padding(.horizontal, 32)

                    benefits
                        .padding(.top, 18)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity)
            }

            // Everything involved in the decision is pinned, as on the paywall.
            priceCard
                .padding(.horizontal, 20)
                .padding(.top, 8)

            onceNotice
                .padding(.horizontal, 20)
                .padding(.top, 10)

            claimButton
                .padding(.horizontal, 20)
                .padding(.top, 12)

            Text("\(viewModel.introPriceString) billed today for your first year, then \(viewModel.fullPriceString)/year. Cancel anytime in App Store settings.")
                .font(.manropeMedium(size: 12))
                .foregroundColor(secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 28)
                .padding(.top, 10)

            footerLinks
                .padding(.bottom, 8)
        }
    }

    /// Same anatomy as the selected `PlanRow`: black badge bar over a white
    /// body, 5pt corners, 1.5pt black stroke.
    private var priceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(viewModel.savingsPercent.map { "\($0)% off your first year" } ?? "Discounted first year")
                .font(.manropeMedium(size: 14))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 3)
                .background(Color.wingmanBlack)

            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Yearly Plan")
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(.wingmanBlack)

                    HStack(spacing: 6) {
                        Text(viewModel.fullPriceString)
                            .strikethrough(true, color: secondary)
                        Text("\(viewModel.introPriceString) first year")
                            .foregroundColor(.wingmanBlack)
                    }
                    .font(.manropeSemiBold(size: 12))
                    .foregroundColor(secondary)
                }

                Spacer()

                if let perMonth = viewModel.introPricePerMonthString {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("only \(perMonth)")
                            .font(.manropeSemiBold(size: 16))
                            .foregroundColor(.wingmanBlack)
                        Text("per month")
                            .font(.manropeSemiBold(size: 12))
                            .foregroundColor(secondary)
                    }
                }
            }
            .padding(16)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 5))
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.wingmanBlack, lineWidth: 1.5)
        )
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(ticks, id: \.self) { benefit($0) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func benefit(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image("check")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .foregroundColor(.wingmanBlack)
                .frame(width: 16, height: 16)
                .padding(.top, 2)
            Text(text)
                .font(.manropeMedium(size: 16))
                .foregroundColor(.wingmanBlack)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var onceNotice: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "eye.slash")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.wingmanBlack)
            Text("You\u{2019}ll only see this once. Close it and this price is gone for good.")
                .font(.manropeMedium(size: 13))
                .foregroundColor(.wingmanBlack)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.customLightGray)
        .clipShape(RoundedRectangle(cornerRadius: 5))
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
