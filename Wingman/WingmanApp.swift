//
//  WingmanApp.swift
//  Wingman
//
//  Created by Adnan Khan on 29/11/2025.
//

import SwiftUI
import Auth  // for User.id on authManager.currentUser (RevenueCat identity fallback)
import GoogleSignIn
import UserNotifications
import RevenueCat
import RevenueCatUI
import BackgroundTasks
import PostHog
import FacebookCore

// Facebook SDK needs application(_:didFinishLaunchingWithOptions:) and
// applicationDidBecomeActive(_:) hooks, which SwiftUI's App protocol doesn't
// expose directly — hence this thin AppDelegate bridged in via
// @UIApplicationDelegateAdaptor below.
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        #if DEBUG
        // Verbose SDK logging so the console shows every event payload and
        // network round-trip to Meta's Graph API — temporary, for diagnosing
        // whether events are actually being sent/accepted.
        Settings.shared.loggingBehaviors = [.appEvents, .networkRequests]
        #endif
        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        AppEvents.shared.activateApp()
    }
}

@main
struct WingmanApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .preferredColorScheme(.light) // Force Light Mode
                // App-wide Dynamic Type ceiling — pins the whole app to the
                // default text size (`.large`). Our custom fonts opt into
                // Dynamic Type (Font+Manrope `relativeTo:`), but the UI is
                // built from fixed-size containers designed at the default
                // size, so larger system text sizes clip/truncate across the
                // app (paywall + landing carousels, Courses card titles, the
                // Home streak badge, …). This is an UPPER BOUND only: users at
                // or below default are unaffected; only enlarged-text users are
                // capped back to default — trading a broken layout for a
                // working one. TEMPORARY: relax per screen as layouts are made
                // to grow (@ScaledMetric heights, .fixedSize on wrapping text).
                // The feature-gate paywall keeps its own clamp — it's a sheet,
                // which doesn't reliably inherit this environment value.
                .dynamicTypeSize(...DynamicTypeSize.large)
                .onOpenURL { url in
                    // Handle Google Sign-In callback URL
                    GIDSignIn.sharedInstance.handle(url)
                    // Handle Facebook App Links / SDK callback URL
                    ApplicationDelegate.shared.application(
                        UIApplication.shared,
                        open: url,
                        sourceApplication: nil,
                        annotation: [UIApplication.OpenURLOptionsKey.annotation: Any?.none as Any]
                    )
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    // Clear notification badge when app enters foreground
                    clearNotificationBadge()
                    // Refresh subscription status when app returns to foreground
                    refreshSubscriptionStatus()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Clear notification badge when app becomes active
                    clearNotificationBadge()
                }
        }
    }
    
    // MARK: - Clear Notification Badge
    private func clearNotificationBadge() {
        log("🔔 App became active - clearing notification badge")
        NotificationManager.shared.clearNotificationBadgeAndDelivered()
    }
    
    // MARK: - Refresh Subscription Status
    private func refreshSubscriptionStatus() {
        log("🔄 WingmanApp: Refreshing subscription status on foreground")
        Task {
            await SubscriptionManager.shared.refreshSubscriptionStatus()
        }
    }
}


struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @StateObject private var featureFlags = FeatureFlags.shared

    /// Offline escape hatch for the post-demo ask, deliberately session-scoped.
    ///
    /// A hard wall with no exit bricks the app for anyone whose RevenueCat
    /// offerings fetch fails — they can't buy (no prices) and can't leave. So
    /// PaywallView keeps a dismiss affordance when `offerings == nil` even in
    /// hard mode, and taking it sets this flag rather than the persisted
    /// `hasDismissedPostDemoWall`. The user gets into the app for this launch;
    /// the ask returns on the next cold start.
    ///
    /// This is also what guarantees an App Reviewer who force-quits sees a
    /// working app rather than an inescapable paywall.
    @State private var bypassWallThisSession = false

    /// Whether RootView should be showing `LandingView`.
    ///
    /// Kept as one condition so `LandingView` occupies exactly one branch of the
    /// routing chain — see the comment at its use site for why two branches
    /// silently destroyed its state mid-tap.
    ///
    /// True while the user has not finished onboarding AND either has not
    /// started an anonymous pass yet (a genuinely new install) or is in the
    /// middle of one. It stays true across `startAnonymousOnboarding()` flipping
    /// `isLegacyAnonymousUser` and across the guest session arriving, which is
    /// exactly the stability the view needs.
    ///
    /// Deliberately false for an authenticated user with incomplete onboarding
    /// (`hasSession`, not legacy): they belong in the main flow's OnboardingView,
    /// not back on Landing.
    private var showLanding: Bool {
        guard !authManager.hasCompletedOnboarding else { return false }
        return authManager.isLegacyAnonymousUser || !authManager.hasSession
    }

    var body: some View {
        ZStack {
            Group {
                // MARK: - Session Check in Progress
                if authManager.isCheckingSession {
                    let _ = log("🎯 RootView: Checking session...")
                    SplashView()

                // MARK: - Authenticated User Flow
                //
                // Ex-subscribers (whose subscription has lapsed) flow through
                // this branch to MainTabView — the same as free users who
                // dismissed the paywall. Per-feature subscription gating inside
                // MainTabView presents the paywall on specific tap → enter
                // transitions (Daily Practice, Log Encounter, lesson entry,
                // scenario tap). Completed progress remains visible; it's read
                // from local/cloud storage and is not gated on subscription.
                // MARK: - Landing / anonymous onboarding in progress
                //
                // ONE branch, deliberately. `LandingView` must appear exactly
                // once in this chain: SwiftUI gives each branch of an
                // if/else-if its own identity, so the *same* view in two
                // branches is destroyed and rebuilt when the condition moves
                // between them, discarding its `@StateObject` and `@State`.
                //
                // That bit us: tapping "Get started" flips
                // `isLegacyAnonymousUser`, which used to move RootView from the
                // final `else` into a separate branch here. LandingView was
                // rebuilt mid-tap — the carousel jumped back to the first slide
                // (fresh `LandingViewModel`) and `navigateToOnboarding` reset to
                // false, so the push was swallowed and the button appeared to
                // need two presses.
                //
                // `showLanding` keeps the condition true across that flag change
                // (and across the guest session arriving), so the branch index
                // never moves and the view keeps its state.
                //
                // Holding it also keeps the OnboardingView that LandingView
                // pushed mounted for the whole anonymous pass, instead of
                // letting `hasSession` swap in a second, different instance
                // once the guest session lands — which on a slow connection
                // restarted onboarding under the user.
                //
                // Ending the pass (`completeAnonymousOnboarding` sets
                // `hasCompletedOnboarding`) drops this branch and hands over
                // cleanly, by which point nothing is in flight to lose.
                } else if showLanding {
                    let _ = log("🎯 RootView: Showing Landing (anonymous pass: \(authManager.isLegacyAnonymousUser))")
                    LandingView()

                // Guests route through here too. `hasSession` — not
                // `isAuthenticated` — is the correct question: a guest holds a
                // real `auth.users` row, so every per-user table, RLS policy and
                // `currentUserId` guard works for them, and the whole point of
                // this plan is that they reach the app without an account.
                // `isAuthenticated` stays narrower ("has a permanent account")
                // because that is what the Phase F account ask keys off.
                } else if authManager.hasSession {
                    let _ = log("🎯 RootView: User HAS a session (guest: \(authManager.isGuestSession))")

                    // ✅ 1) Onboarding questions not finished
                    if !authManager.hasCompletedQuestions {
                        let _ = log("🎯 RootView: Showing OnboardingView (questions NOT completed)")
                        NavigationStack {
                            OnboardingView()
                        }

                    // ✅ 2) Questions finished, rating ask not yet seen →
                    //    show RatingPromptView. Gated on `!effectivePaywallFlowCompleted`
                    //    so existing paying users (who already passed the
                    //    paywall) never route back here after the update —
                    //    they go straight to MainTabView below. The
                    //    "effective" form treats an active RC entitlement as
                    //    equivalent to having completed the flow, which
                    //    self-heals reinstall / new-device cases where the
                    //    flag was wiped but the entitlement is still valid.
                    } else if !authManager.effectivePaywallFlowCompleted && !authManager.hasSeenRatingPrompt {
                        let _ = log("🎯 RootView: Showing RatingPromptView (rating prompt NOT seen)")
                        NavigationStack {
                            RatingPromptView()
                        }

                    // ✅ 3) Questions + rating ack'd → show Paywall
                    } else if !authManager.effectivePaywallFlowCompleted {
                        let _ = log("🎯 RootView: Showing PaywallView (paywall flow NOT completed)")
                        NavigationStack {
                            PaywallView(authManager: authManager, isDismissible: true, source: .onboarding)
                        }

                    // ✅ 3b) Just purchased, still a guest → ask for an account.
                    //
                    // Placed BEFORE 4a on purpose: it therefore catches a
                    // purchase made on *either* paywall (onboarding or
                    // post-demo) with one condition instead of two branches.
                    //
                    // Skippable by design — see AuthContext.afterPurchase. The
                    // user has already been charged, so a wall here would brick
                    // the app for anyone whose OAuth fails. Declining sets the
                    // persisted flag and falls through to 4a; linking clears
                    // `isGuestSession` and does the same.
                    } else if authManager.isGuestSession
                                && authManager.shouldShowPostPurchaseAccountAsk {
                        let _ = log("🎯 RootView: Showing post-purchase account ask (guest subscriber)")
                        NavigationStack {
                            AuthView(
                                mode: .signup,
                                context: .afterPurchase,
                                onSkip: { authManager.markPostPurchaseAccountAskSeen() }
                            )
                        }

                    // ✅ 4a) Paying user → straight in, full access.
                    } else if authManager.hasActiveSubscription {
                        let _ = log("🎯 RootView: Showing MainTabView (active subscription)")
                        MainTabView()

                    // ✅ 4b) Demo not yet spent → MainTabView in DEMO MODE.
                    //    The mascot walkthrough runs here and hands out one
                    //    scenario + one lesson. Approach logging is free and
                    //    stays free. Phase 6 adds the walkthrough itself; until
                    //    then this branch is behaviourally identical to the old
                    //    MainTabView case, with the existing feature gates
                    //    still doing the gating.
                    } else if !authManager.hasCompletedFreeDemo {
                        let _ = log("🎯 RootView: Showing MainTabView (DEMO MODE — free demo not yet spent)")
                        MainTabView()

                    // ✅ 4c) Demo spent, ask not yet answered → the post-demo
                    //    ask, at peak intent. This is a route rather than a
                    //    sheet on purpose: it makes hard-vs-soft a single
                    //    `isDismissible` value on a screen that is already in
                    //    the right place, so flipping the PostHog flag needs no
                    //    structural change.
                    //
                    //    `bypassWallThisSession` is the offline escape hatch —
                    //    see PaywallView's dismiss overlay. It is deliberately
                    //    session-scoped and NOT persisted, so the ask re-arms on
                    //    the next cold start.
                    } else if !authManager.hasDismissedPostDemoWall && !bypassWallThisSession {
                        let _ = log("🎯 RootView: Showing PaywallView (POST-DEMO ask — source=postDemo, hard=\(featureFlags.postDemoWallIsHard))")
                        NavigationStack {
                            PaywallView(
                                authManager: authManager,
                                isDismissible: !featureFlags.postDemoWallIsHard,
                                onDismiss: {
                                    // Soft mode only: the hard-mode overlay is
                                    // the offline hatch, which routes through
                                    // onOfflineBypass below instead.
                                    authManager.markPostDemoWallDismissed()
                                },
                                onOfflineBypass: {
                                    log("🚧 RootView: offline escape hatch taken — bypassing wall for this session only")
                                    bypassWallThisSession = true
                                },
                                source: .postDemo
                            )
                        }

                    // ✅ 4d) Ask answered (or bypassed) → MainTabView, gated.
                    } else {
                        let _ = log("🎯 RootView: Showing MainTabView (post-demo, gated)")
                        MainTabView()
                    }
                
                // MARK: - Legacy Anonymous Flow (no Supabase session)
                //
                // Reachable only when a guest session could not be created —
                // `guestSessionsEnabled` off, or bootstrap failed and has not
                // yet retried. Such a user has no `user_id`, so every
                // progress write and the scenario fetch itself would fail
                // (PracticeServiceProtocol.swift:107 throws .notAuthenticated).
                // Onboarding and the paywall are entirely local, so they still
                // work; the wall at the end is what stops a user reaching an
                // app that cannot function for them.
                //
                // This branch disappears with the legacy flag in Phase H.
                } else if authManager.isLegacyAnonymousUser && authManager.hasCompletedOnboarding {
                    let _ = log("🎯 RootView: Legacy anonymous (no session) — completed onboarding")

                    if !authManager.effectivePaywallFlowCompleted && !authManager.hasSeenRatingPrompt {
                        let _ = log("🎯 RootView: Legacy anonymous - showing RatingPromptView")
                        NavigationStack {
                            RatingPromptView()
                        }

                    } else if !authManager.effectivePaywallFlowCompleted {
                        let _ = log("🎯 RootView: Legacy anonymous - showing PaywallView")
                        NavigationStack {
                            PaywallView(authManager: authManager, isDismissible: true, source: .onboarding)
                        }

                    } else {
                        let _ = log("🎯 RootView: Legacy anonymous - requiring account creation (no session available)")
                        NavigationStack {
                            AuthView(mode: .signup, context: .requiredAfterPaywall)
                        }
                    }

                // MARK: - Unauthenticated User Flow
                //
                // Terminal branch. Everything that reaches here has no session,
                // has already seen onboarding, and is not mid-anonymous-pass —
                // i.e. a returning user who signed out or whose session died.
                // The Landing case is handled above by `showLanding`; it must
                // NOT also appear here, or switching between the two would
                // rebuild it and wipe its state.
                } else {
                    let _ = log("🎯 RootView: User NOT authenticated, but HAS seen onboarding")
                    NavigationStack {
                        AuthView(mode: .login)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
            .animation(.easeInOut(duration: 0.3), value: authManager.isGuestSession)
            .animation(.easeInOut(duration: 0.3), value: authManager.isCheckingSession)
            .animation(.easeInOut(duration: 0.3), value: authManager.isLegacyAnonymousUser)
            .animation(.easeInOut(duration: 0.3), value: authManager.hasActiveSubscription)
            // Paywall #1 → forced account creation is driven by
            // `effectivePaywallFlowCompleted`, which was missing from this list.
            // Without it that branch swap was an un-animated hard cut: the
            // paywall vanished and AuthView appeared in a single frame, which
            // reads as a glitch rather than a step. Every other route change in
            // RootView crossfades; this one now does too.
            //
            // The remaining sibling, `hasCompletedQuestions` (onboarding →
            // rating prompt), still cuts. Left alone deliberately — out of
            // scope here, and worth its own before/after look.
            .animation(.easeInOut(duration: 0.3), value: authManager.effectivePaywallFlowCompleted)
            // Rating prompt → paywall #1, for the same reason as the line
            // above; this was the before/after that note asked for. The cut
            // left the paywall's very first frame fully exposed, with nothing
            // to blend it, so anything the paywall renders before its plans are
            // ready snapped into view as a flash. PaywallViewModel now seeds
            // from RevenueCat's cache so that frame usually holds the real
            // plans, and this crossfade covers the cases where it can't
            // (cold cache, offline).
            .animation(.easeInOut(duration: 0.3), value: authManager.hasSeenRatingPrompt)
            // Same reasoning as the line above, for the two transitions the
            // walkthrough introduces. Both were unreachable in production until
            // W6 gave `markFreeDemoCompleted()` a caller, so neither had ever
            // rendered before.
            //
            // The first is the money moment — the mascot's last beat hands off
            // to the post-demo ask — and an un-animated swap there reads as the
            // app glitching rather than as the next step.
            .animation(.easeInOut(duration: 0.3), value: authManager.hasCompletedFreeDemo)
            .animation(.easeInOut(duration: 0.3), value: authManager.hasDismissedPostDemoWall)
        }
        .task {
            // Step 1: Configure RevenueCat on app launch (MUST be first)
            RevenueCatManager.shared.configure()
            // A cached guest session can arrive before this point (AuthManager
            // observes auth from its own init), in which case its RevenueCat
            // identity was deferred rather than crashing on an unconfigured SDK.
            authManager.applyPendingGuestRevenueCatIdentity()

            // Step 1b: PostHog analytics. Runs on a detached background task
            // so SDK setup and /decide response processing don't compete with
            // the main thread during OnboardingView's first render — this is
            // the fix for the launch-time onboarding lag we previously
            // diagnosed. Every event carries an `environment` super-property
            // so dashboards can filter dev/simulator traffic out of prod
            // metrics (filter `environment = "prod"` on all insights).
            //
            // Identity is deliberately NOT established here. posthog-ios spends
            // its single anonymous→identified merge on the FIRST identify() and
            // refuses every later one — `PostHogSDK.swift:576` only merges
            // `if hasDifferentDistinctId, !isIdentified`, and the else branch
            // just logs "already identified" without even updating the stored
            // distinct_id.
            //
            // This used to call `identify(AnonymousUserManager.anonymousUserId)`
            // for unauthenticated users, which burned that one merge on a local
            // UUID no other system has ever seen. Every subsequent
            // identify(supabaseUserId) — observeAuthState()'s .signedIn and
            // .initialSession, and adoptGuestIdentity() — was silently dropped,
            // so PostHog could never be joined to Supabase or RevenueCat and
            // each subscriber existed as two persons: one holding the funnel,
            // one holding the revenue events from the RevenueCat webhook.
            //
            // Leaving the SDK on its own anonymous id until sign-in is the same
            // shape RevenueCat already uses deliberately (RevenueCatManager
            // configures with no appUserID for exactly this reason) — and it is
            // what makes the later identify a real anonymous→identified
            // transfer that carries `$anon_distinct_id`.
            let posthogSetup = Task.detached(priority: .utility) {
                // The new init(projectToken:host:) is async (replaces the
                // deprecated init(apiKey:host:)), so it must be awaited. The
                // SDK's setup/register/identify themselves remain synchronous.
                let config = await PostHogConfig(
                    projectToken: Constants.POSTHOG_PROJECT_TOKEN,
                    host: Constants.POSTHOG_HOST
                )
                config.captureApplicationLifecycleEvents = false

                // Deliberately left false. This flag only drives the swizzled
                // UIViewController.viewDidAppear autocapture, which in a
                // SwiftUI app resolves to the WindowGroup's root
                // UIHostingController on every transition — one meaningless
                // name repeated for every screen. The manual
                // PostHogSDK.screen() call behind the .trackScreenView()
                // modifiers on each screen is NOT gated on this flag, so
                // screen tracking works with it off and stays free of
                // hosting-controller noise.
                config.captureScreenViews = false

                // Session replay. screenshotMode is required for SwiftUI:
                // the default renderer walks the UIKit view hierarchy, which
                // can't see SwiftUI's internal view tree.
                config.sessionReplay = true
                config.sessionReplayConfig.screenshotMode = true

                // General UI is recorded unmasked so replays are actually
                // readable. Note this flag covers static SwiftUI `Text` as
                // well as editable fields — the SDK treats both as
                // text-based views — so leaving it on blacks out essentially
                // the whole app, which is what it was doing before.
                //
                // Sensitive screens are masked individually with
                // `.postHogMask()` instead: AuthView, SettingsSheet,
                // EditProfileSheet, LogApproachBottomSheet and
                // ApproachesLoggedListView. Anything new that renders an
                // email, a real name, or free text about a third party needs
                // the same treatment — this flag will no longer catch it.
                config.sessionReplayConfig.maskAllTextInputs = false

                // Every image in the app is a bundled asset (course art,
                // scenario covers, onboarding statistic illustrations).
                // There is no camera, photo picker or user upload anywhere,
                // so nothing user-supplied can surface here.
                config.sessionReplayConfig.maskAllImages = false

                // Deliberately left at its default of `true`. This masks
                // views that don't belong to our process — system-rendered
                // surfaces such as the StoreKit purchase sheet. Turning it
                // off would gain nothing (the app has no image or contact
                // pickers, the other things it covers) while removing the
                // only guard on payment UI.
                // config.sessionReplayConfig.maskAllSandboxedViews = false

                PostHogSDK.shared.setup(config)

                Analytics.registerEnvironment()

                // One-time repair for installs that already ran a build which
                // identified against the local anonymous UUID. The SDK's
                // `isIdentified` flag is persisted in its own storage and
                // survives launches, so simply removing the call above does
                // nothing for those devices — every later identify() would keep
                // hitting the "already identified" branch forever.
                //
                // reset() clears the flag and the distinct_id, so the next
                // identify() is a genuine anonymous→identified transfer. Cost is
                // that the pre-repair anonymous person is orphaned, which is why
                // this runs exactly once per install, before any identify().
                //
                // Declared locally rather than as a file-scope constant: a
                // global `let` here is main-actor-isolated by inference, and
                // reading it from this detached task is an error under the
                // Swift 6 language mode. Versioned so a future repair can be
                // forced by bumping the suffix.
                let identityResetKey = "posthog_identity_reset_v2"
                if !UserDefaults.standard.bool(forKey: identityResetKey) {
                    UserDefaults.standard.set(true, forKey: identityResetKey)
                    PostHogSDK.shared.reset()
                    // reset() also wipes the super-property registered a few
                    // lines above, so it has to go back on. See
                    // Analytics.registerEnvironment().
                    Analytics.registerEnvironment()
                }

                // The SDK is now up and the environment super-property is on,
                // so anything captured during the window above can be replayed.
                // Deliberately before the feature-flag fetch: that's a network
                // round-trip, and the buffered events — LandingView's screen
                // view, most of all — have already waited long enough. Nothing
                // below this point depends on flags being loaded.
                Analytics.markReady()

                // Feature flags. `read()` first so a cache warmed by a previous
                // session applies immediately, then `refresh()` to pull current
                // values for this distinct_id. Both hop to the main actor
                // internally; this task is deliberately off the main thread.
                await FeatureFlags.shared.read()
                await FeatureFlags.shared.refresh()
            }

            // Identify the restored session, but only once the SDK is actually
            // up. `observeAuthState()` starts from `AuthManager.init()`, so
            // `.initialSession` can fire before `setup(_:)` has run — and every
            // PostHog call made before setup is silently dropped
            // (`isEnabled()` returns false and logs). Without this hop a
            // returning user's identify is simply lost for the whole launch,
            // which would leave the seam this change exists to close still open.
            //
            // Mirrors the deferred-identity pattern
            // `applyPendingGuestRevenueCatIdentity()` already uses above for the
            // same class of ordering problem.
            //
            // A session that arrives *after* this point needs nothing here: the
            // identify calls in `observeAuthState()` and `adoptGuestIdentity()`
            // now work, because nothing has spent the merge.
            Task {
                await posthogSetup.value
                authManager.applyPendingPostHogIdentity()
            }

            // Step 2: Initialize subscription monitoring (after RevenueCat is ready)
            SubscriptionManager.shared.initializeMonitoring()
            authManager.setupSubscriptionMonitoring()
            
            // Step 3: Clear any existing notification badge on app launch
            NotificationManager.shared.clearNotificationBadgeAndDelivered()
            
            // Step 4: Restore session gracefully on app launch
            await authManager.restoreSessionGracefully()

            #if DEBUG
            // Phase B test hooks. Runs after restore so -forceGuestBootstrap
            // exercises the same ordering a real bootstrap would see.
            await authManager.applyDebugGuestOverrides()
            #endif

            // Step 4b: Retry guest bootstrap for someone who already chose to
            // continue without an account but ended a previous launch with no
            // session — bootstrap failed, the device was offline, or they
            // onboarded before this shipped.
            //
            // Gated on `isLegacyAnonymousUser` (set by startAnonymousOnboarding,
            // i.e. they tapped "Skip for now") on purpose. Without the gate this
            // fires on the very first launch of a fresh install and mints a
            // guest session before LandingView is even shown — which silently
            // removes the Create Account / Log In / Skip choice. LandingView is
            // deliberately kept, so the session is created by the skip button,
            // and this only ever repairs a session that should already exist.
            if authManager.isLegacyAnonymousUser {
                await authManager.bootstrapGuestSessionIfNeeded()
            }

            // Step 5: Setup notifications on app launch
            // (Periodic subscription checks are already started inside
            // initializeMonitoring() above — calling startPeriodicChecks()
            // here invalidated and recreated the timer and fired a third
            // redundant initial check on every cold launch.)
            NotificationManager.shared.setupNotificationsOnLaunch()
        }
        .onChange(of: authManager.isAuthenticated) { newValue in
            log("\n🔔 RootView detected isAuthenticated change: \(newValue)")
            log("   - hasCompletedQuestions: \(authManager.hasCompletedQuestions)")
            log("   - hasCompletedPaywallFlow: \(authManager.hasCompletedPaywallFlow)")
            log("   - hasCompletedOnboarding: \(authManager.hasCompletedOnboarding)")
            log("   - hasCompletedFreeDemo: \(authManager.hasCompletedFreeDemo)")
            log("   - hasDismissedPostDemoWall: \(authManager.hasDismissedPostDemoWall)")
            log("   - freeLessonId: \(authManager.freeLessonId ?? "unclaimed")")

            // Set RevenueCat user ID when user authenticates.
            //
            // Deliberately NO logout branch here. `isAuthenticated` can flip
            // false for reasons that are not a sign-out — most notably
            // restoreSessionGracefully()'s catch racing .initialSession — and
            // RevenueCat's logOut() abandons the identified customer for a
            // fresh anonymous one, orphaning any active subscription with it.
            // Deliberate exits log RevenueCat out at their own call sites:
            // the .signedOut handler in observeAuthState() (both sign-out
            // buttons route through client.auth.signOut()) and
            // deleteAccount().
            if newValue {
                // Fallback to AuthManager's user: currentUserId reads the
                // Supabase client's own state, which can lag the auth event
                // that set isAuthenticated. Previously a nil here silently
                // skipped identification and the entitlement never followed
                // the user.
                if let userId = SupabaseManager.shared.currentUserId ?? authManager.currentUser?.id.uuidString {
                    RevenueCatManager.shared.setUserID(userId)
                } else {
                    log("🚨 RootView: authenticated but no user id resolvable — RevenueCat identity NOT set")
                }
            }
        }
        .onChange(of: authManager.hasActiveSubscription) { newValue in
            log("\n🔔 RootView detected hasActiveSubscription change: \(newValue)")
            log("   - Expiry date: \(authManager.subscriptionExpiryDate?.formatted() ?? "nil")")
        }
        .onChange(of: authManager.hasCompletedFreeDemo) { newValue in
            log("\n🔔 RootView detected hasCompletedFreeDemo change: \(newValue)")
            log("   - hasDismissedPostDemoWall: \(authManager.hasDismissedPostDemoWall)")
            log("   - postDemoWallIsHard: \(featureFlags.postDemoWallIsHard)")
            // Flipping this also releases the free lesson credit, so the
            // claim state belongs in the same dump.
            log("   - freeLessonId: \(authManager.freeLessonId ?? "unclaimed")")
        }
        .onChange(of: authManager.hasDismissedPostDemoWall) { newValue in
            log("\n🔔 RootView detected hasDismissedPostDemoWall change: \(newValue)")
        }
        .onChange(of: authManager.hasCompletedQuestions) { newValue in
            log("\n🔔 RootView detected hasCompletedQuestions change: \(newValue)")
        }
        .onChange(of: authManager.hasCompletedPaywallFlow) { newValue in
            log("\n🔔 RootView detected hasCompletedPaywallFlow change: \(newValue)")
        }
        .onChange(of: authManager.hasSeenRatingPrompt) { newValue in
            log("\n🔔 RootView detected hasSeenRatingPrompt change: \(newValue)")
        }
    }
}
