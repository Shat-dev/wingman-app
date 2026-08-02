//
//  PaywallViewModel.swift
//  Wingman
//
//  Created by Adnan Khan on 18/12/2025.
//

import Foundation
import SwiftUI
import Combine
import RevenueCat
import StoreKit
import PostHog
import FacebookCore

/// Thrown by `loadOfferings()` when the RevenueCat offerings fetch doesn't
/// resolve within its deadline. Caught by the same block that handles
/// network errors, so the UI surfaces the existing "Can't load pricing"
/// error state with its Try Again button.
private struct PaywallTimeoutError: Error {}

@MainActor
final class PaywallViewModel: ObservableObject {
    
    // MARK: - Dependencies
    weak var authManager: AuthManager?
    /// Origin tag for PostHog paywall_purchase_* events. Set by the
    /// presenting `PaywallView` in its `.onAppear`. Defaults to `.onboarding`
    /// so events are still attributable if a code path forgets to set it,
    /// but the compiler-required `source` on `PaywallView.init` makes that
    /// path effectively unreachable.
    var source: PaywallSource = .onboarding
    
    // MARK: - RevenueCat
    /// True from construction, because `init()` unconditionally starts a load.
    ///
    /// Defaulting to `false` was a false statement about the object's state,
    /// and it had a visible cost: the very first `body` evaluation of
    /// `PaywallView` saw `offerings == nil` *and* `isLoading == false`, so it
    /// fell through to the "Can't load pricing" branch. A load that has not
    /// started yet is not a load that has failed. Starting `true` makes that
    /// branch unreachable until an attempt has actually run and lost.
    @Published var isLoading = true
    @Published var offerings: Offerings?
    @Published var selectedPackage: Package?
    @Published var isPurchasing = false
    @Published var error: String?
    @Published var showAlert = false

    /// True when the most recent load loop exhausted every attempt without
    /// reaching RevenueCat.
    ///
    /// Deliberately distinct from `offerings == nil`. Now that offerings are
    /// seeded from RevenueCat's on-disk cache in `init()`, an offline user can
    /// have perfectly good-looking prices on screen that they cannot actually
    /// transact against — StoreKit will fail the purchase. `offerings == nil`
    /// used to be a reliable proxy for "this user cannot buy"; it no longer is,
    /// and `PaywallView.pricingUnavailable` (which gates the non-dismissible
    /// wall's escape hatch) needs the real answer.
    @Published private(set) var lastLoadFailed = false

    /// Per-product intro-offer eligibility from RevenueCat. Populated after
    /// offerings load and after a failed restore. Empty dictionary means
    /// "not yet known" — computed properties below treat that as eligible
    /// (optimistic default) so the 95% first-time-user path is unaffected by
    /// a pending or failed eligibility check.
    @Published var introEligibility: [String: IntroEligibility] = [:]

    // MARK: - Carousel
    @Published var currentPage: Int = 0

    // MARK: - In-app Safari
    /// Drives a `.sheet(item:)` that presents Privacy/Terms in an
    /// SFSafariViewController modal instead of bouncing out to Safari.app.
    @Published var safariLink: IdentifiableURL?

    let pages: [PaywallPage] = [
        PaywallPage(
            imageName: "paywall_1",
            bullets: [
                "Stop overthinking your next move",
                "Feel more natural each time you talk",
                "Learn core social and flirting skills through daily reps"
            ]
        ),
        PaywallPage(
            imageName: "paywall_2",
            bullets: [
                "Develop the skills most men were never taught",
                "Master mindset, communication, flirting, and approach mechanics step-by-step",
                "Learn how to create attraction & interest"
            ]
        ),
        PaywallPage(
            imageName: "paywall_3",
            bullets: [
                "Stop guessing what to say next",
                "Practice real encounters through scenario-based games",
                "Be ready for any situation before it happens"
            ]
        ),
        PaywallPage(
            imageName: "paywall_4",
            bullets: [
                "See your confidence grow with real data",
                "Track your approaches, reflections, and progress",
                "Stay motivated as you watch yourself improve"
            ]
        )
    ]

    // MARK: - Plan
    @Published var selectedPlan: SubscriptionPlan = .yearly
    
    // MARK: - Computed Properties
    var yearlyPackage: Package? {
        return offerings?.current?.package(identifier: "yearly") ??
               offerings?.current?.annual
    }
    
    var monthlyPackage: Package? {
        return offerings?.current?.package(identifier: "monthly") ??
               offerings?.current?.monthly
    }
    
    var yearlyPrice: String {
        return yearlyPackage?.storeProduct.localizedPriceString ?? ""
    }

    var monthlyPrice: String {
        return monthlyPackage?.storeProduct.localizedPriceString ?? ""
    }
    
    var currentPackage: Package? {
        return selectedPlan == .yearly ? yearlyPackage : monthlyPackage
    }

    /// A localized, currency-correct zero — "$0.00", "€0,00", "£0.00", "¥0" —
    /// for the free-trial CTA. Built from the selected StoreKit product's own
    /// price formatter (the same one behind `localizedPriceString`) so a
    /// non-US storefront never sees a hardcoded dollar amount, and so the
    /// fraction-digit convention matches the price rendered on the plan card
    /// right above the button.
    ///
    /// Falls back to "$0.00" only if StoreKit hands us no formatter — which
    /// can't happen on the path that reads this, since `continueButton` is
    /// rendered solely when `offerings != nil`.
    var zeroPriceString: String {
        guard let formatter = currentPackage?.storeProduct.priceFormatter,
              let formatted = formatter.string(from: NSNumber(value: 0)) else {
            return "$0.00"
        }
        return formatted
    }

    // MARK: - Trial Eligibility
    //
    // `.eligible` and `.unknown` both map to "show trial UI" — `.unknown` is
    // what RevenueCat returns for a fresh install with no App Store receipt,
    // and Apple will grant the trial in that case. Only an authoritative
    // `.ineligible` or `.noIntroOfferExists` hides the trial badge, matching
    // Apple's Guideline 3.1.2 requirement that trial claims be accurate.

    var isYearlyTrialEligible: Bool {
        guard let id = yearlyPackage?.storeProduct.productIdentifier else { return true }
        return isEligibleStatus(introEligibility[id]?.status)
    }

    var isMonthlyTrialEligible: Bool {
        guard let id = monthlyPackage?.storeProduct.productIdentifier else { return true }
        return isEligibleStatus(introEligibility[id]?.status)
    }

    func isTrialEligible(for plan: SubscriptionPlan) -> Bool {
        return plan == .yearly ? isYearlyTrialEligible : isMonthlyTrialEligible
    }

    /// Nil (not-yet-checked) → eligible (optimistic). `.unknown` (fresh install,
    /// no receipt) → eligible per RevenueCat's own recommendation.
    private func isEligibleStatus(_ status: IntroEligibilityStatus?) -> Bool {
        guard let status else { return true }
        switch status {
        case .eligible, .unknown: return true
        case .ineligible, .noIntroOfferExists: return false
        @unknown default: return true
        }
    }

    // MARK: - Load orchestration
    /// Handle to the in-flight offerings load. Overlapping triggers (init,
    /// `PaywallView.onAppear`, the Try Again button, and the connectivity
    /// observer) coalesce onto this single retry loop instead of stacking
    /// concurrent fetches.
    private var loadTask: Task<Void, Never>?

    /// Automatic attempts before the inline retry UI is surfaced. Sized so a
    /// brief blip — a captive-portal redirect completing, an App Store /
    /// RevenueCat latency spike, a dead-zone that clears — recovers without
    /// the user ever seeing an error, while still bounding total wait.
    private let maxLoadAttempts = 3

    /// Combine store for the connectivity observer.
    private var cancellables = Set<AnyCancellable>()

    init() {
        // Seed from RevenueCat's synchronous cache so the first frame can
        // render real plans rather than any pre-content state. This is exactly
        // what `cachedOfferings` exists for — RevenueCat's own documentation on
        // it says it "allows initializing state to ensure that UI can be loaded
        // from the very first frame".
        //
        // The cache is reliably warm by the time any paywall mounts:
        // `RevenueCatManager.configure()` fetches offerings during app launch,
        // and the user crosses the whole of onboarding plus the rating prompt
        // before paywall #1 appears.
        //
        // The `isConfigured` check is load-bearing, not defensive:
        // `Purchases.shared` calls `fatalError` when the SDK has not been
        // configured, and `configure()` deliberately returns early in StoreKit
        // testing mode.
        if Purchases.isConfigured, let cached = Purchases.shared.cachedOfferings {
            self.offerings = cached
            self.selectedPackage = yearlyPackage
        }

        observeConnectivity()
        loadOfferings()
    }

    func selectPlan(_ plan: SubscriptionPlan) {
        selectedPlan = plan
        selectedPackage = plan == .yearly ? yearlyPackage : monthlyPackage
        log("🧾 Selected plan: \(plan.rawValue)")
    }

    // MARK: - RevenueCat Methods
    /// Public entry point. Coalesces with any in-flight load, then runs the
    /// retry loop. Safe to call repeatedly from `.onAppear`, the Try Again
    /// button, and the connectivity observer — duplicate triggers no-op while
    /// a load is already running.
    func loadOfferings() {
        guard loadTask == nil else {
            log("ℹ️ PaywallViewModel: loadOfferings already running — coalescing duplicate trigger")
            return
        }
        loadTask = Task { [weak self] in
            await self?.runLoadLoop()
            self?.loadTask = nil
        }
    }

    /// Attempts the offerings fetch with linear backoff, surfacing the failure
    /// — via analytics and the inline retry UI — only once every automatic
    /// attempt is exhausted. Keeps `isLoading` true across the whole loop so
    /// the view shows the loading state (not the error state) mid-retry.
    private func runLoadLoop() async {
        isLoading = true

        // Offerings seeded from the cache in `init()` arrive WITHOUT their
        // eligibility data, and `isEligibleStatus` treats "not yet known" as
        // eligible by design. For a trial-ineligible user (lapsed trial on this
        // Apple ID, returning subscriber) that combination would render a
        // "3-day Free Trial" badge and a "Try for $0.00" CTA until the refresh
        // below finished — a false trial claim under Apple Guideline 3.1.2,
        // held for however long the network took.
        //
        // Resolving eligibility up front narrows that window to the local
        // receipt check. Only runs on the seeded path: on a cold load
        // `offerings` is nil here and there is nothing to be wrong about yet.
        if offerings != nil && introEligibility.isEmpty {
            await loadIntroEligibility()
        }

        // Full retry budget only for a cold load (no offerings yet). A refresh
        // triggered by re-appearing already has prices on screen, so a failure
        // is invisible to the user and doesn't warrant hammering the network —
        // this preserves the previous single-attempt behavior for that case.
        let attemptBudget = (offerings == nil) ? maxLoadAttempts : 1
        var lastError: Error?

        for attempt in 1...attemptBudget {
            do {
                let fetchedOfferings = try await fetchOfferingsWithTimeout()
                self.offerings = fetchedOfferings

                // Auto-select yearly package by default
                self.selectedPackage = yearlyPackage

                log("📦 PaywallViewModel: Loaded offerings (attempt \(attempt)/\(attemptBudget))")

                // Fetch intro-offer eligibility for both packages. Non-throwing
                // API — failures resolve to `.unknown`, which our optimistic
                // default treats as eligible, so this call cannot regress the
                // existing first-time-user UX.
                await loadIntroEligibility()

                lastError = nil
                break
            } catch {
                lastError = error
                log("❌ PaywallViewModel: Offerings load attempt \(attempt)/\(attemptBudget) failed: \(error)")

                // Backoff before the next try (skipped after the final attempt).
                // Linear 1s, 2s — long enough to let a recovering network or a
                // clearing captive portal settle, short enough not to feel dead.
                if attempt < attemptBudget {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 1_000_000_000)
                }
            }
        }

        isLoading = false
        lastLoadFailed = (lastError != nil)

        // Surface the failure only after every automatic attempt is exhausted
        // AND we still have nothing to show. A failed background refresh that
        // still has cached offerings on screen stays intentionally silent.
        if let lastError, self.offerings == nil {
            reportOfferingsFailure(lastError, attempts: attemptBudget)
        }

        // Fire after isLoading flips so the UI unblocks immediately;
        // the capture itself is a background metadata write that we
        // don't want to gate paywall rendering on.
        if self.offerings != nil {
            await captureStoreContextIfNeeded()
        }
    }

    /// Races the RevenueCat offerings fetch against a 15s timeout so a hanging
    /// StoreKit call (cached sandbox account from prior TestFlight use, captive
    /// WiFi, Apple server stall, etc.) doesn't leave a single attempt spinning
    /// forever. On timeout we throw `PaywallTimeoutError`, which `runLoadLoop`
    /// treats as a retryable failure. 15s is generous enough not to
    /// false-positive on slow cellular (typical offerings response is <2s on
    /// healthy networks, 3-5s on slow mobile) while still short enough that a
    /// stalled attempt gives way to the next retry promptly.
    private func fetchOfferingsWithTimeout() async throws -> Offerings {
        try await withThrowingTaskGroup(of: Offerings.self) { group in
            group.addTask {
                try await Purchases.shared.offerings()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 15_000_000_000)
                throw PaywallTimeoutError()
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    /// Auto-retry the offerings load the moment connectivity is restored, so a
    /// user who reached the paywall in a dead zone or behind a not-yet-passed
    /// captive portal gets a populated paywall without tapping Try Again. Only
    /// acts when we still have no offerings and nothing is already loading, so
    /// it stays dormant once pricing is on screen.
    private func observeConnectivity() {
        NetworkMonitor.shared.$isConnected
            .removeDuplicates()
            .sink { [weak self] connected in
                guard connected else { return }
                Task { @MainActor [weak self] in
                    // `lastLoadFailed` is part of the condition, not just
                    // `offerings == nil`. Cache-seeded offerings mean a user
                    // who came back online can be holding stale prices with
                    // `offerings != nil`, which under the old guard would never
                    // retry for the rest of the session — leaving those prices
                    // unrefreshed and, on a hard wall, the escape hatch stuck
                    // open. Retrying clears both.
                    guard let self,
                          self.offerings == nil || self.lastLoadFailed,
                          self.loadTask == nil else { return }
                    log("📶 PaywallViewModel: Connectivity restored — auto-retrying offerings")
                    self.loadOfferings()
                }
            }
            .store(in: &cancellables)
    }

    /// PostHog: the paywall couldn't load pricing after every automatic retry.
    /// Previously this path emitted no event — a failed load left only a
    /// `paywall_viewed` with nothing after it, so the cause had to be guessed
    /// from session replays. `error_type` buckets timeout (captive/slow link)
    /// vs a thrown network/backend error; `is_connected` is the device's link
    /// state at give-up time; raw `error_domain`/`error_code` are included so
    /// buckets can be refined from the data without shipping new code.
    private func reportOfferingsFailure(_ error: Error, attempts: Int) {
        let nsError = error as NSError
        log("🛑 PaywallViewModel: Offerings failed after \(attempts) attempt(s): \(error)")
        PostHogSDK.shared.capture("paywall_offerings_failed", properties: [
            "source": source.rawValue,
            "error_type": classifyOfferingsError(error),
            "error_domain": nsError.domain,
            "error_code": nsError.code,
            "is_connected": NetworkMonitor.shared.isConnected,
            "attempts": attempts
        ])
    }

    /// Coarse bucket for the offerings-load failure. Kept deliberately
    /// dependency-light — matched on Foundation/RevenueCat error *domains*
    /// rather than SDK enum symbols that can drift across versions — with the
    /// raw code carried alongside in the event for exactness.
    private func classifyOfferingsError(_ error: Error) -> String {
        if error is PaywallTimeoutError { return "timeout" }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain { return "network" }
        if nsError.domain == "RevenueCat.ErrorCode" {
            // RevenueCat surfaces connectivity failures as networkError (10)
            // and offlineConnectionError (35); everything else on this domain
            // is a backend/config response.
            return (nsError.code == 10 || nsError.code == 35) ? "network" : "backend"
        }
        return "other"
    }

    /// Fetches per-product intro-offer eligibility from RevenueCat and stores
    /// it on `introEligibility`. Safe to call repeatedly (RC caches receipts
    /// locally). Non-throwing; failures leave unresolved products at
    /// `.unknown`, which the eligibility computed properties treat as eligible.
    private func loadIntroEligibility() async {
        guard let yearlyID = yearlyPackage?.storeProduct.productIdentifier,
              let monthlyID = monthlyPackage?.storeProduct.productIdentifier else {
            return
        }
        let result = await Purchases.shared.checkTrialOrIntroDiscountEligibility(
            productIdentifiers: [yearlyID, monthlyID]
        )
        self.introEligibility = result
        log("🎫 PaywallViewModel: Eligibility — yearly=\(result[yearlyID]?.status.rawValue ?? -1), monthly=\(result[monthlyID]?.status.rawValue ?? -1)")
    }

    /// Reads App Store storefront country (StoreKit 2) and currency
    /// (from any loaded StoreProduct), then delegates the write to
    /// `AuthManager.captureStoreContext` which handles auth-gating,
    /// per-user idempotency, and the actual `user_metadata` update.
    private func captureStoreContextIfNeeded() async {
        // Country from StoreKit 2 storefront (nil on simulator/offline).
        var country: String? = nil
        if let storefront = await Storefront.current {
            country = storefront.countryCode
        }

        // Currency from a loaded StoreProduct — yearly preferred, monthly fallback.
        let currency = yearlyPackage?.storeProduct.currencyCode
            ?? monthlyPackage?.storeProduct.currencyCode

        await authManager?.captureStoreContext(country: country, currency: currency)
    }
    
    func continueTapped() async -> Bool {
        guard let package = currentPackage else {
            self.error = "Please select a subscription plan"
            self.showAlert = true
            return false
        }
        
        return await purchase(package)
    }
    
    func purchase(_ package: Package) async -> Bool {
        isPurchasing = true

        // Plan label derived from the package's product identifier.
        let plan: String = {
            if package.storeProduct.productIdentifier == Constants.YEARLY_PRODUCT_ID { return "yearly" }
            if package.storeProduct.productIdentifier == Constants.MONTHLY_PRODUCT_ID { return "monthly" }
            return "unknown"
        }()
        // PostHog: purchase initiated. Captured before the StoreKit call so
        // we have a denominator even when network or sheet errors prevent
        // the success / failure branches from running.
        PostHogSDK.shared.capture("paywall_purchase_started", properties: [
            "plan": plan,
            "product_id": package.storeProduct.productIdentifier,
            "source": source.rawValue
        ])

        do {
            let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(package: package)

            // RevenueCat does not throw on user cancellation of the Apple payment
            // sheet — it returns with userCancelled = true. Bail before the
            // entitlement check so we don't misreport a dismissed sheet as a
            // completed-but-missing-entitlement error.
            if userCancelled {
                log("🚫 PaywallViewModel: User cancelled purchase")
                isPurchasing = false
                return false
            }

            // Check if user has the Wingman Pro entitlement
            let entitlement = customerInfo.entitlements[Constants.ENTITLEMENT_ID]
            let hasEntitlement = entitlement?.isActive == true

            if hasEntitlement {
                log("✅ PaywallViewModel: Purchase successful")
                log("   - Entitlement active: \(hasEntitlement)")
                log("   - Expiry date: \(entitlement?.expirationDate?.formatted() ?? "No expiry")")

                // PostHog: purchase confirmed by RevenueCat entitlement. Read
                // `customerInfo.entitlements` directly here — do NOT read
                // `authManager.hasActiveSubscription`; that flag is updated
                // asynchronously via NotificationCenter and may not have
                // flipped yet at this point in the call stack.
                let isTrial = entitlement?.periodType == .trial
                // "Bought without a permanent account" — the number this whole
                // guest-session change exists to move. The legacy flag would
                // now read true for guests *and* for the vanishing no-session
                // case, conflating them.
                let isAnon = authManager?.isAuthenticated != true
                PostHogSDK.shared.capture("paywall_purchase_succeeded", properties: [
                    "plan": plan,
                    "product_id": package.storeProduct.productIdentifier,
                    "source": source.rawValue,
                    "is_trial": isTrial,
                    "is_anonymous": isAnon
                ])

                // Meta: subscription conversion, so ad campaigns can optimize
                // for/report trial-starts and paid-subscribes rather than just
                // installs. Standard events (not generic Purchase) are what
                // Meta's docs recommend for subscription apps.
                let priceAmount = NSDecimalNumber(decimal: package.storeProduct.price).doubleValue
                let currency = package.storeProduct.currencyCode ?? "USD"
                if isTrial {
                    AppEvents.shared.logEvent(
                        .startTrial,
                        valueToSum: priceAmount,
                        parameters: [.currency: currency, .contentID: package.storeProduct.productIdentifier]
                    )
                } else {
                    AppEvents.shared.logEvent(
                        .subscribe,
                        valueToSum: priceAmount,
                        parameters: [.currency: currency, .contentID: package.storeProduct.productIdentifier]
                    )
                }

                // Store purchase info for later linking ONLY when there is no
                // Supabase session at all.
                //
                // Deliberately not `isAnon` (which means "no permanent
                // account"): a guest has a real user id, RevenueCat is already
                // identified as that id, and linking preserves it — so there is
                // nothing to link later. Worse, stashing it here arms
                // `needsRevenueCatLinking`, and if that guest ever reached the
                // legacy `.signedIn` sync path it would trigger an
                // identified→identified `logIn` and strand the entitlement —
                // the exact failure Phase D removed.
                if authManager?.hasSession != true {
                    AnonymousUserManager.shared.storeRevenueCatPurchase(customerInfo: customerInfo)
                    log("💰 PaywallViewModel: Stored no-session purchase for linking")
                }

                // Apply the authoritative customerInfo from the purchase
                // result synchronously BEFORE the network refresh. This is
                // RC's own definitive answer — using it here means the
                // SubscriptionGateModifier auto-dismiss (which keys off
                // authManager.hasActiveSubscription) fires reliably even if
                // the follow-up network refresh below fails (e.g. connection
                // drops immediately after the StoreKit transaction). The
                // refresh still runs to invalidate the RC cache for any
                // subsequent reads.
                SubscriptionManager.shared.handleCustomerInfoUpdate(customerInfo, error: nil)

                // 🔄 Refresh subscription status immediately after purchase
                log("🔄 PaywallViewModel: Refreshing subscription status after purchase...")
                await SubscriptionManager.shared.refreshSubscriptionStatus()

                isPurchasing = false
                return true
            } else {
                self.error = "Purchase completed but entitlement not found. Please contact support."
                self.showAlert = true
                isPurchasing = false
                return false
            }

        } catch {
            // Handle RevenueCat specific errors using the error directly
            let nsError = error as NSError
            if nsError.code == 1 {
                // User cancelled — don't surface error UI, don't fire
                // PostHog failure event (cancellation is not a failure).
                log("🚫 PaywallViewModel: User cancelled purchase")
            } else {
                switch nsError.code {
                case 2: // Store problem
                    self.error = "Store is currently unavailable. Please try again later."
                    self.showAlert = true
                case 3: // Purchase not allowed
                    self.error = "Purchases are not allowed on this device"
                    self.showAlert = true
                case 4: // Payment pending
                    self.error = "Payment is pending approval"
                    self.showAlert = true
                default:
                    self.error = "Purchase failed. Please try again."
                    self.showAlert = true
                }
                log("❌ PaywallViewModel: Purchase failed: \(error.localizedDescription)")
                // PostHog: purchase failure (excluding user cancellation).
                // `error_code` is the RevenueCat NSError code; no PII.
                PostHogSDK.shared.capture("paywall_purchase_failed", properties: [
                    "plan": plan,
                    "product_id": package.storeProduct.productIdentifier,
                    "source": source.rawValue,
                    "error_code": nsError.code
                ])
            }

            isPurchasing = false
            return false
        }
    }
    
    // MARK: - Footer Links
    func openPrivacy() {
        if let url = URL(string: Constants.PRIVACY_POLICY_URL) {
            safariLink = IdentifiableURL(url: url)
        }
    }
    
    func openRestore() async {
        isLoading = true
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            let hasEntitlement = customerInfo.entitlements[Constants.ENTITLEMENT_ID]?.isActive == true
            
            if hasEntitlement {
                self.error = "Purchases restored successfully!"
                self.showAlert = true
                log("✅ PaywallViewModel: Purchases restored")
                
                // 🔄 Refresh subscription status after restore
                log("🔄 PaywallViewModel: Refreshing subscription status after restore...")
                await SubscriptionManager.shared.refreshSubscriptionStatus()
            } else {
                self.error = "No active subscriptions found to restore"
                self.showAlert = true
                log("⚠️ PaywallViewModel: No purchases to restore")

                // Re-run eligibility after a restore that didn't grant access.
                // The restore writes the App Store receipt to disk, which lets
                // RevenueCat give an authoritative `.ineligible` for a user
                // who's already used their trial on this Apple ID — updating
                // the paywall copy correctly.
                await loadIntroEligibility()
            }
        } catch {
            self.error = "Failed to restore purchases. Please try again."
            self.showAlert = true
            log("❌ PaywallViewModel: Restore failed: \(error)")
        }
        
        isLoading = false
    }
    
    func openTerms() {
        if let url = URL(string: Constants.TERMS_CONDITIONS_URL) {
            safariLink = IdentifiableURL(url: url)
        }
    }
}
