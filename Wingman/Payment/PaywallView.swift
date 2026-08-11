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

    /// The ask at the end of the mascot walkthrough, once the user has spent
    /// their free scenario and free lesson. This is the peak-intent moment the
    /// walkthrough exists to set up, and the purchase rate here versus
    /// `onboarding` is the number that decides whether the wall gets hardened.
    ///
    /// Raw value left implicit ("postDemo") to match `featureGate` — the
    /// `source` property's existing values are camelCase, and mixing
    /// conventions inside one property makes PostHog filters error-prone.
    case postDemo
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

    /// Escape hatch for the non-dismissible post-demo wall when pricing can't
    /// be loaded.
    ///
    /// A wall with no exit is only safe while the user can actually buy. If
    /// RevenueCat is unreachable there are no prices to show, so the user can
    /// neither purchase nor leave — the app is bricked. When this closure is
    /// provided, the dismiss affordance stays available in that failure state
    /// even with `isDismissible == false`, and taking it calls this instead of
    /// `onDismiss`, so the caller can distinguish "declined the offer" from
    /// "couldn't see the offer" and avoid persisting the former.
    let onOfflineBypass: (() -> Void)?

    /// Origin of this paywall presentation. Tagged onto every PostHog
    /// paywall_* event so funnels can separate the post-onboarding paywall
    /// from feature-gate paywalls. Required by the compiler at every call
    /// site to make this an explicit decision.
    let source: PaywallSource

    /// Called immediately after this view captures a `paywall_dismissed`.
    ///
    /// Exists for the one presentation style this view cannot see the exit of:
    /// as a sheet (`.subscriptionGate`), the user can swipe down, which closes
    /// the sheet without running either of the in-view controls below. Those
    /// dismissals were silently absent from `paywall_dismissed` entirely.
    ///
    /// The host therefore reports them from the sheet's own `onDismiss`, and
    /// uses this callback to know when NOT to — otherwise every X-tap and
    /// every purchase would be counted twice.
    ///
    /// Nil for the routing-level presentations (onboarding, post-demo), which
    /// are branches in RootView rather than sheets and cannot be swiped away.
    let onDismissReported: (() -> Void)?

    // PostHog: emit `paywall_viewed` exactly once per mount, even if SwiftUI
    // re-fires `.onAppear` on incidental view re-mounts.
    @State private var didLogPaywallView = false

    // PostHog: stamped when the paywall becomes visible (same guarded block
    // that fires `paywall_viewed`), so `time_on_screen_seconds` on the
    // selection and dismissal events measures from first appearance rather
    // than from an incidental re-mount.
    @State private var appearedAt: Date?

    // MARK: - Adaptive carousel sizing
    //
    // The carousel is MEASURED, not constant. Two earlier attempts used
    // hand-computed heights (a flat 405, then 350/250 split on `isSmallPhone`)
    // and both clipped, for the same reason: the constants were derived from
    // page 1's bullet count, while the densest page wraps to six lines on a
    // 375pt-wide screen. A paging TabView clips rather than grows, so any
    // constant shorter than the tallest page truncates that page's value props
    // — and the enclosing ScrollView cannot rescue it, because the TabView's
    // frame fits inside the scroll content perfectly well.
    //
    // `isSmallPhone` was also the wrong axis: it keys on screen HEIGHT, while
    // what actually drives content height is WIDTH (text wrapping). That is
    // why the 13 mini (375x812 — tall enough to be classed "not small", narrow
    // enough to wrap like an SE) clipped as well.
    //
    // Measuring removes the guesswork. It also makes the layout
    // Dynamic-Type-correct for free, since the bullets are measured at the
    // user's real text size — which is the precondition the `.large` ceiling
    // further down is waiting on.

    /// Height the ScrollView actually receives — whatever the pinned commitment
    /// block leaves over. Read from the ScrollView's own geometry rather than
    /// computed from screen size, so safe areas and the sheet-vs-fullscreen
    /// presentation difference are accounted for without special-casing.
    @State private var availableCarouselSpace: CGFloat = 0

    /// Natural height of the tallest page's bullet block. Grows monotonically:
    /// a paging TabView need not lay out off-screen pages up front, so a
    /// high-water mark stops the carousel resizing under the user as they swipe
    /// onto a denser page. The copy is static, so it never needs to shrink.
    @State private var maxBulletsHeight: CGFloat = 0

    /// Illustration floor. Stops the image absorbing every point of a squeeze
    /// and collapsing into an unreadable scribble (the SE regression).
    private let illustrationMinHeight: CGFloat = 100

    /// The original design size, and the ceiling every 390-402pt phone still
    /// resolves to. Never lowered — see `illustrationMaxHeight`.
    private let illustrationBaseMaxHeight: CGFloat = 220

    /// Share of the carousel the illustration may claim on screens tall enough
    /// to have slack. ~0.65 lands the illustration just shy of the space
    /// available on a Pro Max, leaving the trailing Spacer near zero.
    private let illustrationHeightFraction: CGFloat = 0.65

    /// Illustration ceiling.
    ///
    /// Proportional rather than fixed, because every iPhone in the fleet shares
    /// essentially one aspect ratio (390x844, 393x852, 402x874 and 440x956 are
    /// all 0.460-0.462), so a Pro Max is not a different shape — it is the same
    /// shape ~12% larger. A fixed 220pt ceiling meant the illustration could
    /// not grow into that extra height, so the slack pooled in the trailing
    /// Spacer as a ~124pt void between the bullets and the page dots. Scaling
    /// the ceiling instead reproduces the same composition at a larger size,
    /// with no width constraint and no side margins.
    ///
    /// `max` against the base is the safety property: the ceiling can never
    /// fall below what shipped, so the illustration can only ever grow, never
    /// shrink. On 390-402pt phones the image is space-limited far below 220
    /// anyway, so the ceiling is not the binding constraint there and nothing
    /// changes — which is why this is a Pro Max-only visual change without
    /// needing a device check to enforce it.
    ///
    /// Note this deliberately does NOT feed `carouselHeight` (which derives
    /// `needed` from the FLOOR): the carousel's height, the page-dot position,
    /// scrolling and the pinned block are all unaffected by this value.
    private var illustrationMaxHeight: CGFloat {
        max(illustrationBaseMaxHeight, carouselHeight * illustrationHeightFraction)
    }

    /// The illustration's own 20/15 vertical padding.
    private let illustrationPadding: CGFloat = 35

    /// The page-indicator row: 8pt dots plus its 12/20 padding.
    private let pageIndicatorHeight: CGFloat = 40

    /// Height handed to the paging TabView.
    ///
    /// The `max` of "space on offer" and "space the tallest page actually
    /// needs" is the entire fix. The second term makes clipping structurally
    /// impossible; only once that holds does the surrounding ScrollView become
    /// a genuine safety valve, because any overflow now lands on the ScrollView
    /// instead of inside the TabView.
    private var carouselHeight: CGFloat {
        // Pre-measurement first pass. A mid-range seed keeps the one-frame
        // settle imperceptible rather than a collapse-then-expand jump.
        guard availableCarouselSpace > 0, maxBulletsHeight > 0 else { return 350 }

        let needed = illustrationMinHeight + illustrationPadding + maxBulletsHeight
        let offered = availableCarouselSpace - pageIndicatorHeight
        return max(offered, needed)
    }

    init(
        authManager: AuthManager? = nil,
        isDismissible: Bool = false,
        onDismiss: (() -> Void)? = nil,
        onOfflineBypass: (() -> Void)? = nil,
        source: PaywallSource,
        onDismissReported: (() -> Void)? = nil
    ) {
        self.authManager_init = authManager
        self.isDismissible = isDismissible
        self.onDismiss = onDismiss
        self.onOfflineBypass = onOfflineBypass
        self.source = source
        self.onDismissReported = onDismissReported
    }

    /// Whether the user cannot realistically complete a purchase here.
    ///
    /// This is deliberately BROADER than the condition `pricingStatusSection` /
    /// `pricingRetryButton` render on, and no longer mirrors it. Offerings are
    /// now seeded from RevenueCat's on-disk cache, so `offerings != nil` no
    /// longer implies the user can transact: an offline user sees cached prices
    /// and a working-looking Continue button whose StoreKit purchase will fail.
    /// Gating the escape hatch on `offerings == nil` alone would therefore trap
    /// exactly the user it exists to rescue.
    ///
    /// `lastLoadFailed` closes that gap. Erring toward showing the hatch is the
    /// safe direction: the worst case is a hard wall becoming dismissible for
    /// someone on a flaky connection, versus an inescapable paywall.
    private var pricingUnavailable: Bool {
        viewModel.offerings == nil || viewModel.lastLoadFailed
    }

    /// Whether to render the X. Normally just `isDismissible`, but a
    /// non-dismissible wall must still open when pricing can't load, otherwise
    /// an offline user is trapped on a screen with nothing to buy.
    private var showsDismissAffordance: Bool {
        isDismissible || (onOfflineBypass != nil && pricingUnavailable)
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
        // to a referral flow that was removed from the app.
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
                // ONLY the carousel and its page dots live in here. Everything
                // involved in the actual decision — plan cards, CTA, trial
                // disclosure, footer — is pinned below and can never scroll
                // out of view. The ScrollView is retained purely as a safety
                // valve: if the carousel doesn't fit on a given device the
                // illustration scrolls a little, which is a far better failure
                // mode than a paging TabView clipping the bullets.
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // MARK: - Carousel
                        TabView(selection: $viewModel.currentPage) {
                            ForEach(viewModel.pages.indices, id: \.self) { index in
                                let page = viewModel.pages[index]

                                VStack(spacing: 0) {

                                    // Image
                                    //
                                    // Ranged, not fixed: the illustration is
                                    // the element that gives when space is
                                    // short, since the `.fixedSize` bullets
                                    // below must keep every line. The floor is
                                    // load-bearing — without it the image
                                    // absorbs the entire shortfall and shrinks
                                    // to ~45pt on an SE. With it, a squeeze
                                    // that cannot be met becomes a short scroll
                                    // of the carousel instead, which is the far
                                    // better failure mode.
                                    Image(page.imageName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(
                                            minHeight: illustrationMinHeight,
                                            maxHeight: illustrationMaxHeight
                                        )
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
                                    // Reports this page's bullet height. The
                                    // key reduces with `max`, so the value
                                    // arriving at the ScrollView is the tallest
                                    // page's, whichever page that happens to be
                                    // and whatever the user's text size.
                                    .background(
                                        GeometryReader { geo in
                                            Color.clear.preference(
                                                key: BulletsHeightKey.self,
                                                value: geo.size.height
                                            )
                                        }
                                    )

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

                    }
                }
                .frame(maxHeight: .infinity)
                // Reports the height the ScrollView was actually given. A
                // `.background` reader rather than wrapping the ScrollView in a
                // GeometryReader: the reader must not influence sizing, only
                // observe it. Because `carouselHeight` feeds the scroll
                // CONTENT and never this frame (fixed by `maxHeight: .infinity`
                // above the pinned block), there is no measurement feedback
                // loop — the layout settles in one extra pass.
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: AvailableCarouselSpaceKey.self,
                            value: geo.size.height
                        )
                    }
                )
                .onPreferenceChange(AvailableCarouselSpaceKey.self) { height in
                    availableCarouselSpace = height
                }
                .onPreferenceChange(BulletsHeightKey.self) { height in
                    maxBulletsHeight = max(maxBulletsHeight, height)
                }

                // MARK: - Pinned commitment block
                //
                // Prices, trial terms and the button all sit OUTSIDE the
                // ScrollView above, so everything the user needs in order to
                // decide is on screen on every device. Previously the plans and
                // the disclosure were the last children of the ScrollView,
                // which meant that on shorter phones the monthly card was
                // clipped by the button bar and the disclosure sat below the
                // fold entirely.
                //
                // Gated on offerings alone — NOT on isLoading — so the moment a
                // package resolves the real plans replace the placeholder, and
                // a background refresh never flickers loaded prices back to a
                // spinner. The retry control doubles as the in-progress
                // indicator in the not-yet-loaded branch.
                if viewModel.offerings != nil {
                    if viewModel.isDiscountWindowActive {
                        discountCountdownBanner
                    }
                    plansSection
                    continueButton
                    // Deliberately BELOW the CTA. The trial promise is already
                    // made twice above it (plan-card badge + button title), so
                    // this line's job is to clear last-second doubt at the
                    // moment of the tap rather than to inform, and keeping it
                    // out of the price→button path shortens that path.
                    //
                    // Placement is NOT conditional on trial eligibility — only
                    // the copy swaps — so the billed-immediately variant, the
                    // one carrying real Guideline 3.1.2 weight, can never be
                    // the version that goes missing.
                    trialDisclosure
                } else {
                    pricingStatusSection
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
            //
            // For a NON-dismissible wall the same guarantee has to hold, so
            // `showsDismissAffordance` keeps the X when pricing failed to
            // load. That path reports a distinct outcome and calls
            // `onOfflineBypass`, letting the caller grant a session-scoped
            // bypass instead of recording a decline the user never made.
            if showsDismissAffordance {
                Button {
                    HapticManager.shared.tap()
                    let isOfflineBypass = !isDismissible
                    // PostHog: user actively dismissed the paywall
                    // without purchasing. Captured at the action site
                    // so both the routing and feature-gate dismissal
                    // paths emit the same event with explicit source.
                    PostHogSDK.shared.capture(
                        "paywall_dismissed",
                        properties: paywallEventProperties([
                            "outcome": isOfflineBypass
                                ? "bypassed_pricing_unavailable"
                                : "dismissed_without_purchase",
                            "dismiss_method": "close_button"
                        ])
                    )
                    onDismissReported?()
                    if isOfflineBypass {
                        onOfflineBypass?()
                    } else if let onDismiss = onDismiss {
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
                .buttonStyle(ScalePressStyle())
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

            // After `selectPlan`, which would otherwise overwrite the
            // re-pointed selection with the standard yearly package. Only does
            // anything on the feature-gate paywall, and only for a user whose
            // 30-minute recovery window is still running.
            viewModel.startDiscountWindowIfEligible()

            // PostHog: paywall_viewed — the top of the conversion funnel.
            // Guarded against SwiftUI's incidental re-mounts.
            if !didLogPaywallView {
                didLogPaywallView = true
                appearedAt = Date()
                PostHogSDK.shared.capture("paywall_viewed", properties: [
                    "source": source.rawValue,
                    "is_dismissible": isDismissible
                ])

                // Experiment exposure for `post_demo_wall_hard`, recorded
                // where the variant is actually experienced rather than on
                // the launch path. Deliberately inside the one-shot guard —
                // the SDK de-dupes per value per session anyway, but relying
                // on that would mean re-mounts still depended on SDK
                // internals to stay correct.
                if source == .postDemo {
                    FeatureFlags.shared.recordPostDemoWallExposure()
                }
            }
        }
        .onDisappear {
            log("📱 PaywallView disappeared")
        }
        .trackScreenView("Paywall")
    }

    // MARK: - Discount Countdown
    //
    // Shown only while `PaywallViewModel` is actually serving the discounted
    // product, so the clock and the price can never disagree: when it reaches
    // zero the view model swaps the package back and this disappears in the
    // same update.
    //
    // A real deadline, which is the only reason it is here at all. The
    // recovery modal deliberately refuses a countdown because nothing about
    // that screen expires; this one does expire, and hiding that from the user
    // would be the actual dishonesty.
    private var discountCountdownBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 13, weight: .medium))

            Text(viewModel.discountSavingsPercent.map { "Your \($0)% discount ends in \(OfferCountdown.format(viewModel.discountRemaining))" }
                 ?? "Your discount ends in \(OfferCountdown.format(viewModel.discountRemaining))")
                .font(.manropeSemiBold(size: 14))
                // Announced on a timer, not on every tick: VoiceOver reading a
                // new second aloud once a second would make the screen unusable.
                .accessibilityLabel("Discount ends in \(Int(viewModel.discountRemaining / 60)) minutes")
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.wingmanBlack)
        .padding(.bottom, 12)
    }

    // MARK: - Plans
    /// The real, purchasable plans. Rendered only when offerings have loaded;
    /// unchanged from the original content-state markup.
    private var plansSection: some View {
        VStack(spacing: 12) {

            // Yearly Plan
            PlanRow(
                title: "Yearly Plan",
                price: viewModel.yearlyPackage.map { "\(calculateWeeklyPrice($0, chargedPrice: viewModel.yearlyChargedPrice)) per week" } ?? "",
                weekly: viewModel.yearlyPrice,
                weeklySubtitle: viewModel.isDiscountWindowActive ? "first year" : "per year",
                isSelected: viewModel.selectedPlan == .yearly,
                badgeText: yearlyBadgeText,
                originalPrice: viewModel.yearlyOriginalPrice
            ) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.selectPlan(.yearly)
                }
                PostHogSDK.shared.capture(
                    "paywall_plan_selected",
                    properties: paywallEventProperties([
                        "plan": "yearly",
                        "is_trial_eligible": viewModel.isYearlyTrialEligible
                    ])
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
                    properties: paywallEventProperties([
                        "plan": "monthly",
                        "is_trial_eligible": viewModel.isMonthlyTrialEligible
                    ])
                )
            }

        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8) // Breathing room before the pinned Continue button
    }

    /// Badge on the yearly card: the discount inside the window, the trial
    /// outside it, never both. They are mutually exclusive by construction —
    /// `isYearlyTrialEligible` returns false while the window is open, because
    /// the discounted product's introductory offer is pay-up-front rather than
    /// a trial.
    private var yearlyBadgeText: String? {
        guard viewModel.selectedPlan == .yearly else { return nil }
        if let percent = viewModel.discountSavingsPercent { return "Save \(percent)% on your first year" }
        return viewModel.isYearlyTrialEligible ? "3-day Free Trial" : nil
    }

    // MARK: - Trial Disclosure
    /// Trial conversion disclosure. The copy flips on eligibility so returning
    /// users who have already burned their trial on this Apple ID see accurate
    /// "billed immediately" messaging (Apple Guideline 3.1.2).
    ///
    /// Rendered by `body` in the pinned block below the CTA, never inside the
    /// ScrollView. This is the strongest objection-killer on the screen and the
    /// ineligible variant is the one with real 3.1.2 weight, so neither may
    /// depend on the user thinking to scroll.
    ///
    /// The 28pt horizontal inset reproduces what this text used to inherit as a
    /// child of `plansSection` (20pt section inset + 8pt of its own), keeping
    /// the line-wrap identical to what shipped.
    private var trialDisclosure: some View {
        Text(disclosureCopy)
            .font(.manropeMedium(size: 12))
            .foregroundColor(Color(hex: "6B7280"))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 28)
            .padding(.bottom, 4)
    }

    /// Three variants, one line, never optional.
    ///
    /// The discounted case is the one with real Guideline 3.1.2 weight: two
    /// different prices across two billing periods, so it has to state both
    /// amounts rather than leaning on "billed immediately". It only applies to
    /// the yearly card — the monthly plan is untouched by the window, so
    /// selecting it must fall straight back to the standard copy.
    private var disclosureCopy: String {
        if viewModel.isDiscountWindowActive, viewModel.selectedPlan == .yearly {
            return "Billed \(viewModel.yearlyPrice) today for your first year. Renews automatically at \(viewModel.yearlyOriginalPrice ?? "")/year after. Cancel anytime in App Store settings."
        }
        return viewModel.isTrialEligible(for: viewModel.selectedPlan)
            ? "No payment now. Cancel anytime before your trial ends."
            : "Billed immediately. Cancel anytime in App Store settings."
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

    /// Label for the primary CTA.
    ///
    /// When the selected plan carries a live free trial, the button states the
    /// actual ask — zero — instead of "Continue". In a paywall context
    /// "Continue" is read as "proceed to being charged", so the trial (the
    /// single strongest objection-killer we have) was being carried only by a
    /// small badge on the plan card and a 12pt disclosure line, while the
    /// element the thumb actually lands on implied the opposite.
    ///
    /// Trial-ineligible users — returning subscribers, anyone whose trial
    /// already lapsed on this Apple ID — keep "Continue", because their
    /// purchase really is billed immediately. Claiming $0 there would be a
    /// false trial claim under Apple Guideline 3.1.2.
    ///
    /// Eligibility is the same `isTrialEligible(for:)` that drives the plan
    /// card's "3-day Free Trial" badge, so badge and button can never
    /// disagree — including on the optimistic pre-check default, where both
    /// treat unknown/not-yet-loaded as eligible.
    private var continueButtonTitle: String {
        // Same words as the button on the recovery modal, for the same offer.
        // A user who came back for the discount should not have to work out
        // whether "Continue" still means the price they left for.
        if viewModel.selectedPlan == .yearly, let percent = viewModel.discountSavingsPercent {
            return "Get \(percent)% off"
        }
        guard viewModel.isTrialEligible(for: viewModel.selectedPlan) else {
            return "Continue"
        }
        return "Try for \(viewModel.zeroPriceString)"
    }

    /// Primary CTA once pricing is available.
    private var continueButton: some View {
        Button {
            HapticManager.shared.tapStrong()
            Task {
                let success = await viewModel.continueTapped()
                if success {
                    // PostHog: paywall ended with a
                    // purchase. Captured here (not from a
                    // shared dismiss handler) so source +
                    // outcome are explicit per call site.
                    PostHogSDK.shared.capture(
                        "paywall_dismissed",
                        properties: paywallEventProperties([
                            "outcome": "purchased",
                            "dismiss_method": "purchase"
                        ])
                    )
                    onDismissReported?()
                    // No referral screen in the flow — complete the paywall directly.
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
                Text(viewModel.isPurchasing ? "Processing..." : continueButtonTitle)
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

    // MARK: - Pinned Retry / Loading Button
    /// Replaces the Continue button while pricing is unavailable. Doubles as
    /// the in-progress indicator: disabled with a spinner and "Loading…" while
    /// the view model is fetching/retrying, tappable "Try Again" once it has
    /// given up. Tapping re-enters `loadOfferings()`, which coalesces safely
    /// with any load already in flight.
    private var pricingRetryButton: some View {
        Button {
            HapticManager.shared.tapStrong()
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
        .buttonStyle(ScalePressStyle())
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
            .buttonStyle(ScalePressStyle())

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
            .buttonStyle(ScalePressStyle())
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
            .buttonStyle(ScalePressStyle())
        }
        .padding(.horizontal, 60)
        .padding(.bottom, 8)
    }

    // MARK: - Helper Methods
    /// - Parameter chargedPrice: what the user is actually billed, when that
    ///   differs from the product's standard price. Inside the discount window
    ///   `storeProduct.price` is still the full $44.99 — deriving the weekly
    ///   rate from it would print the undiscounted per-week figure directly
    ///   beneath the discounted total.
    private func calculateWeeklyPrice(_ package: Package?, chargedPrice: Decimal? = nil) -> String {
        guard let package = package else { return "N/A" }

        let price = chargedPrice ?? package.storeProduct.price
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

// MARK: - Carousel Measurement Keys

/// Height the carousel's ScrollView was given, i.e. what the pinned commitment
/// block left over.
private struct AvailableCarouselSpaceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Height of a carousel page's bullet block.
///
/// Reduces with `max`, so a single reader above the TabView receives the
/// tallest page's height without needing to know which page that is — the
/// point being that the densest page, not page 1, is what the carousel has to
/// be tall enough for.
private struct BulletsHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    PaywallView(source: .onboarding)
}
