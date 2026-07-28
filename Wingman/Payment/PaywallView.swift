//
//  PaywallView.swift
//  Wingman
//
//  Created by Adnan Khan on 17/12/2025.
//

import SwiftUI
import RevenueCat
import PostHog

/// Where the paywall was opened from. Distinguishes the routing-level paywall
/// (post-onboarding mandatory step) from a feature-gate paywall (user tapped
/// a locked feature). Carried as the `source` property on every paywall event
/// so funnels segment cleanly.
enum PaywallSource: String {
    case onboarding
    case featureGate
}

struct PaywallView: View {

    @StateObject private var viewModel = PaywallViewModel()
    @EnvironmentObject var authManager: AuthManager

    // Optional AuthManager for anonymous user purchase tracking
    let authManager_init: AuthManager?

    /// When true, renders an X close button in the top-trailing corner.
    /// Default false preserves the non-dismissible behavior used by legacy
    /// call sites.
    let isDismissible: Bool

    /// Optional override for the X button's dismiss behavior.
    ///
    /// - When `nil` (default): X calls `authManager.completePaywallFlow()`,
    ///   which is the correct behavior for the **routing-level paywall** in
    ///   RootView — it advances the user past the paywall flow so the next
    ///   screen (MainTabView or AuthView signup) can render.
    /// - When provided: X calls the closure instead. This is the correct
    ///   behavior for **feature-gate paywalls** (presented via
    ///   `.subscriptionGate(isPresented:)`), where the user is already past
    ///   the paywall flow (`hasCompletedPaywallFlow` is already true) and
    ///   dismissing just needs to close the sheet — setting the paywall-flow
    ///   flag again would be semantically wrong.
    let onDismiss: (() -> Void)?

    /// Origin of this paywall presentation. Tagged onto every PostHog
    /// paywall_* event so funnels can separate the post-onboarding paywall
    /// from feature-gate paywalls. Required by the compiler at every call
    /// site to make this an explicit decision.
    let source: PaywallSource

    // PostHog: emit `paywall_viewed` exactly once per mount, even if SwiftUI
    // re-fires `.onAppear` on incidental view re-mounts.
    @State private var didLogPaywallView = false

    // PostHog: stamped when the paywall becomes visible (same guarded block
    // that fires `paywall_viewed`), so `time_on_screen_seconds` on the
    // selection and dismissal events measures from first appearance rather
    // than from an incidental re-mount.
    @State private var appearedAt: Date?

    /// Carousel height that scales with Dynamic Type so the bullets (which
    /// already use `.fixedSize`) get more room as text grows instead of being
    /// clipped by the fixed-height paging TabView. Equals the original 405 at
    /// the default text size — no visual change until the app-wide ceiling is
    /// raised above `.large`.
    @ScaledMetric(relativeTo: .body) private var carouselHeight: CGFloat = 405

    init(
        authManager: AuthManager? = nil,
        isDismissible: Bool = false,
        onDismiss: (() -> Void)? = nil,
        source: PaywallSource
    ) {
        self.authManager_init = authManager
        self.isDismissible = isDismissible
        self.onDismiss = onDismiss
        self.source = source
    }

    /// Shared property bag for the paywall interaction events: the existing
    /// `source` tag plus how long the user had been on the screen.
    ///
    /// `time_on_screen_seconds` is omitted rather than zeroed when the
    /// appearance timestamp is missing, so a bug here can never masquerade
    /// in the data as a burst of instantaneous interactions.
    private func paywallEventProperties(_ extra: [String: Any]) -> [String: Any] {
        var properties: [String: Any] = ["source": source.rawValue]
        if let appearedAt {
            properties["time_on_screen_seconds"] = Analytics.elapsedSeconds(since: appearedAt)
        }
        return properties.merging(extra) { _, new in new }
    }

    var body: some View {
        // NOTE: no inner NavigationStack here — both presentation paths
        // wrap PaywallView in a NavigationStack at the call site (RootView
        // for the full-screen post-onboarding paywall, SubscriptionGateModifier
        // for the slide-up sheet). The previously-nested NavigationStack
        // was redundant and only hosted a now-dead `.navigationDestination`
        // to a removed ReferralView flow.
        ZStack {
            VStack(spacing: 0) {
                // MARK: - Scrollable value content (carousel + dots + price area)
                //
                // The value carousel renders in EVERY state now. A slow or
                // failed pricing fetch no longer blanks the whole screen —
                // only the price area below the carousel swaps to a loading /
                // retry state (pricingStatusSection), and the pinned primary
                // button swaps to a retry control (pricingRetryButton). This
                // keeps the user reading the value proposition while the view
                // model's automatic retries / reconnect-retry run underneath.
                //
                // Placed inside a ScrollView so on small devices (SE / mini)
                // the user can reach everything even when total content
                // exceeds the screen height. The primary button and footer
                // below stay pinned to the bottom regardless.
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // MARK: - Carousel
                        TabView(selection: $viewModel.currentPage) {
                            ForEach(viewModel.pages.indices, id: \.self) { index in
                                let page = viewModel.pages[index]

                                VStack(spacing: 0) {

                                    // Image
                                    Image(page.imageName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 220)
                                        .padding(.top, 20)
                                        .padding(.bottom, 15)

                                    // Bullets
                                    VStack(alignment: .leading, spacing: 16) {
                                        ForEach(page.bullets, id: \.self) { bullet in
                                            HStack(alignment: .top, spacing: 12) {
                                                Image("check")
                                                    .resizable()
                                                    .renderingMode(.template)
                                                    .scaledToFit()
                                                    .foregroundColor(.wingmanBlack)
                                                    .frame(width: 16, height: 16)
                                                    .padding(.top, 2)

                                                Text(bullet)
                                                    .font(.manropeMedium(size: 16))
                                                    .foregroundColor(.wingmanBlack)
                                                    .lineSpacing(2)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 17)

                                    Spacer()
                                }
                                .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .frame(height: carouselHeight)

                        // MARK: - Page Indicator
                        HStack(spacing: 8) {
                            ForEach(viewModel.pages.indices, id: \.self) { index in
                                Circle()
                                    .fill(viewModel.currentPage == index ? Color.wingmanBlack : Color.wingmanBlack.opacity(0.2))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 20)

                        // MARK: - Plans (or pricing loading / retry state)
                        //
                        // Gated on offerings alone — NOT on isLoading — so the
                        // moment a package resolves the real plans replace the
                        // placeholder, and a background refresh never flickers
                        // loaded prices back to a spinner.
                        if viewModel.offerings != nil {
                            plansSection
                        } else {
                            pricingStatusSection
                        }
                    }
                }
                .frame(maxHeight: .infinity)

                // MARK: - Pinned primary action
                // Continue (purchase) once pricing is available; otherwise a
                // retry control that doubles as the in-progress indicator.
                if viewModel.offerings != nil {
                    continueButton
                } else {
                    pricingRetryButton
                }

                // MARK: - Pinned Footer Links
                // Shown in every state so existing subscribers can restore
                // their purchase even while offerings are still loading or
                // failed to load.
                footerLinks
            }
            .background(Color.white)
        }
        // MARK: - Dynamic Type stopgap
        //
        // Our custom fonts opt into Dynamic Type (Font+Manrope uses the
        // `relativeTo:` initializer), so bullet text scales with the
        // user's system text-size setting. The carousel below is a fixed
        // 405pt TabView holding a fixed 220pt image, which leaves only a
        // tight ~150pt for the bullets — and a paging TabView *clips*
        // rather than grows. At large system text sizes the bullets
        // overflow that budget and the last line is cut off (seen in
        // PostHog replays).
        //
        // Capping the effective Dynamic Type size here prevents the
        // overflow. This is a TEMPORARY ceiling, not the real fix: the
        // proper solution is to make the carousel grow with the text
        // (adaptive height — @ScaledMetric). Once that lands, raise or
        // remove this clamp.
        //
        // Pinned to `.large` (the default size) rather than a higher
        // ceiling: `.large` reproduces the exact rendering this screen
        // ships with and is designed/tested at, so it CANNOT overflow or
        // truncate — the safest, most minimal stopgap. The cost is that
        // larger-text users see default-size text on this screen until the
        // growth fix restores scaling. Chosen over `.xLarge`, which was
        // borderline on the densest page (page 2).
        .dynamicTypeSize(...DynamicTypeSize.large)
        .overlay(alignment: .topTrailing) {
            // Dismiss affordance for the dismissible paywall paths
            // (initial paywall for free users). Hidden for the
            // subscription-expiry paywall path, which is non-dismissible
            // by design — RootView decides which mode to use.
            //
            // Available on every state (loading / error / content) so a
            // user is never trapped if RevenueCat is slow or offline.
            if isDismissible {
                Button {
                    HapticManager.shared.lightImpact()
                    // PostHog: user actively dismissed the paywall
                    // without purchasing. Captured at the action site
                    // so both the routing and feature-gate dismissal
                    // paths emit the same event with explicit source.
                    PostHogSDK.shared.capture(
                        "paywall_dismissed",
                        properties: paywallEventProperties(["outcome": "dismissed_without_purchase"])
                    )
                    if let onDismiss = onDismiss {
                        onDismiss()
                    } else {
                        authManager.completePaywallFlow()
                    }
                } label: {
                    // Mirrors the AuthView back-chevron treatment: naked
                    // SF Symbol, wingmanBlack, 44×44 tap target. `xmark` is
                    // the chevron-family X (two crossed strokes), and a
                    // smaller point size keeps it visually lighter than
                    // the back chevron — this is an escape hatch, not a CTA.
                    Image(systemName: "xmark")
                        .font(.system(size: 16))
                        .foregroundColor(.wingmanBlack)
                        .frame(width: 44, height: 44, alignment: .center)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, 6)
                .accessibilityLabel("Close paywall")
            }
        }
        .alert("Error", isPresented: $viewModel.showAlert) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            Text(viewModel.error ?? "An error occurred")
        }
        .sheet(item: $viewModel.safariLink) { link in
            SafariView(url: link.url)
                .ignoresSafeArea()
        }
        .onChange(of: viewModel.showAlert) { showing in
            if showing { HapticManager.shared.error() }
        }
        .onAppear {
            // Set AuthManager reference for anonymous user purchase tracking
            let authMgr = authManager_init ?? authManager
            viewModel.authManager = authMgr
            // Pass source through to the view model so purchase events can
            // tag it without re-deriving.
            viewModel.source = source

            // If user is returning to paywall due to subscription expiry,
            // refresh offerings and reset UI state
            log("📱 PaywallView appeared")
            viewModel.loadOfferings()
            viewModel.currentPage = 0
            viewModel.selectPlan(.yearly)

            // PostHog: paywall_viewed — the top of the conversion funnel.
            // Guarded against SwiftUI's incidental re-mounts.
            if !didLogPaywallView {
                didLogPaywallView = true
                appearedAt = Date()
                PostHogSDK.shared.capture("paywall_viewed", properties: [
                    "source": source.rawValue,
                    "is_dismissible": isDismissible
                ])
            }
        }
        .onDisappear {
            log("📱 PaywallView disappeared")
        }
        .postHogScreenView("Paywall")
    }

    // MARK: - Plans
    /// The real, purchasable plans. Rendered only when offerings have loaded;
    /// unchanged from the original content-state markup.
    private var plansSection: some View {
        VStack(spacing: 12) {

            // Yearly Plan
            PlanRow(
                title: "Yearly Plan",
                price: viewModel.yearlyPackage.map { "\(calculateWeeklyPrice($0)) per week" } ?? "",
                weekly: viewModel.yearlyPrice,
                weeklySubtitle: "per year",
                isSelected: viewModel.selectedPlan == .yearly,
                badgeText: (viewModel.selectedPlan == .yearly && viewModel.isYearlyTrialEligible) ? "3-day Free Trial" : nil
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.selectPlan(.yearly)
                }
                PostHogSDK.shared.capture(
                    "paywall_plan_selected",
                    properties: paywallEventProperties(["plan": "yearly"])
                )
            }
            .padding(.bottom,10)

            // Monthly Plan
            PlanRow(
                title: "Monthly Plan",
                price: viewModel.monthlyPackage.map { "\(calculateWeeklyPrice($0)) per week" } ?? "",
                weekly: viewModel.monthlyPrice,
                    weeklySubtitle: "per month",
                    isSelected: viewModel.selectedPlan == .monthly,
                    badgeText: (viewModel.selectedPlan == .monthly && viewModel.isMonthlyTrialEligible) ? "3-day Free Trial" : nil
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.selectPlan(.monthly)
                }
                PostHogSDK.shared.capture(
                    "paywall_plan_selected",
                    properties: paywallEventProperties(["plan": "monthly"])
                )
            }

            // Trial conversion disclosure — copy flips based on eligibility
            // so returning users who've already used their trial see
            // accurate "billed immediately" messaging (Apple 3.1.2).
            Text(viewModel.isTrialEligible(for: viewModel.selectedPlan)
                 ? "No payment now. Cancel anytime before your trial ends."
                 : "Billed immediately. Cancel anytime in App Store settings.")
                .font(.manropeMedium(size: 12))
                .foregroundColor(Color(hex: "6B7280"))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
                .padding(.horizontal, 8)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8) // Breathing room before the pinned Continue button
    }

    // MARK: - Pricing Status (inline loading / error shown under the carousel)
    /// Occupies the price area when offerings aren't available yet. While the
    /// view model is loading (including mid-retry) it shows a spinner; once
    /// every automatic attempt is exhausted it shows the "Can't load pricing"
    /// message — but non-blocking, with the carousel still visible above and
    /// the Try Again control pinned below.
    private var pricingStatusSection: some View {
        VStack(spacing: 16) {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .wingmanBlack))
                    .scaleEffect(1.2)
                Text("Loading subscription options...")
                    .font(.manropeRegular(size: 16))
                    .foregroundColor(.gray)
            } else {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 48, weight: .regular))
                    .foregroundColor(.gray.opacity(0.7))

                Text("Can't load pricing")
                    .font(.manropeSemiBold(size: 22))
                    .foregroundColor(.wingmanBlack)

                Text("Check your connection and try again.")
                    .font(.manropeRegular(size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.bottom, 24)
    }

    // MARK: - Pinned Continue Button
    /// Primary CTA once pricing is available. Unchanged from the original.
    private var continueButton: some View {
        Button {
            HapticManager.shared.mediumImpact()
            Task {
                let success = await viewModel.continueTapped()
                if success {
                    // PostHog: paywall ended with a
                    // purchase. Captured here (not from a
                    // shared dismiss handler) so source +
                    // outcome are explicit per call site.
                    PostHogSDK.shared.capture(
                        "paywall_dismissed",
                        properties: paywallEventProperties(["outcome": "purchased"])
                    )
                    // Referral screen removed from flow — complete paywall directly.
                    // ReferralView.swift is intentionally kept intact for possible future use.
                    authManager.completePaywallFlow()
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
                Text(viewModel.isPurchasing ? "Processing..." : "Continue")
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

    // MARK: - Pinned Retry / Loading Button
    /// Replaces the Continue button while pricing is unavailable. Doubles as
    /// the in-progress indicator: disabled with a spinner and "Loading…" while
    /// the view model is fetching/retrying, tappable "Try Again" once it has
    /// given up. Tapping re-enters `loadOfferings()`, which coalesces safely
    /// with any load already in flight.
    private var pricingRetryButton: some View {
        Button {
            HapticManager.shared.mediumImpact()
            viewModel.loadOfferings()
        } label: {
            HStack(spacing: 8) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
                Text(viewModel.isLoading ? "Loading..." : "Try Again")
                    .font(.manropeSemiBold(size: 16))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color.wingmanBlack.opacity(viewModel.isLoading ? 0.7 : 1.0))
            .cornerRadius(5)
        }
        .disabled(viewModel.isLoading)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
    }

    // MARK: - Footer Links
    /// Privacy / Restore / Terms. Shown in every state; unchanged from the
    /// original markup (identical in both the former error and content states).
    private var footerLinks: some View {
        HStack(spacing: 0) {
            Button {
                viewModel.openPrivacy()
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
                    await viewModel.openRestore()
                }
            } label: {
                HStack(spacing: 4) {
                    if viewModel.isLoading && !viewModel.isPurchasing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.6)
                    }
                    Text("Restore")
                        .font(.manropeMedium(size: 12))
                        .foregroundColor(Color(hex: "6B7280"))
                        .underline()
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
            }
            .disabled(viewModel.isLoading)

            Spacer()

            Button {
                viewModel.openTerms()
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

    // MARK: - Helper Methods
    private func calculateWeeklyPrice(_ package: Package?) -> String {
        guard let package = package else { return "N/A" }

        let price = package.storeProduct.price
        let period = package.storeProduct.subscriptionPeriod

        // Calculate weekly price based on subscription period
        let weeklyPrice: Decimal
        if period?.unit == .year {
            weeklyPrice = price / 52 // 52 weeks in a year
        } else if period?.unit == .month {
            weeklyPrice = price / 4.33 // ~4.33 weeks in a month
        } else {
            weeklyPrice = price
        }

        // Use the same formatter configuration as the original price string
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale.current

        return "only " + (formatter.string(from: weeklyPrice as NSNumber) ?? "$0.00")
    }
}

#Preview {
    PaywallView(source: .onboarding)
}
