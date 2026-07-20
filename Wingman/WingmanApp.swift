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
                } else if authManager.isAuthenticated {
                    let _ = log("🎯 RootView: User IS authenticated")

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

                    // ✅ 3) Questions + rating ack'd → show Paywall (and Referral flow)
                    } else if !authManager.effectivePaywallFlowCompleted {
                        let _ = log("🎯 RootView: Showing PaywallView (paywall flow NOT completed)")
                        NavigationStack {
                            PaywallView(authManager: authManager, isDismissible: true, source: .onboarding)
                        }

                    // ✅ 4) Paywall + Referral finished → MainTabView (Home)
                    } else {
                        let _ = log("🎯 RootView: Showing MainTabView (paywall flow completed)")
                        MainTabView()
                    }
                
                // MARK: - Anonymous User Flow (Skip for now)
                } else if authManager.isAnonymousUser && authManager.hasCompletedOnboarding {
                    let _ = log("🎯 RootView: Anonymous user completed onboarding")

                    // ✅ Anonymous user - questions finished, rating ask not
                    //    yet seen → show RatingPromptView. Gated on
                    //    `!effectivePaywallFlowCompleted` for parity with the
                    //    authenticated flow — anonymous-paid users (who
                    //    completed an in-app purchase before signup) skip
                    //    straight to the forced account-creation step.
                    if !authManager.effectivePaywallFlowCompleted && !authManager.hasSeenRatingPrompt {
                        let _ = log("🎯 RootView: Anonymous user - showing RatingPromptView")
                        NavigationStack {
                            RatingPromptView()
                        }

                    // ✅ Anonymous user - questions + rating ack'd → show Paywall
                    } else if !authManager.effectivePaywallFlowCompleted {
                        let _ = log("🎯 RootView: Anonymous user - showing PaywallView")
                        NavigationStack {
                            PaywallView(authManager: authManager, isDismissible: true, source: .onboarding)
                        }

                    // ✅ Anonymous user - paywall finished → require account creation
                    //
                    // canGoBack: false — this is the *forced* account-creation
                    // step. Allowing back here would let a user who already
                    // purchased (RC entitlement attached to anonymous ID)
                    // bail to LandingView and end up looping through the
                    // paywall again on the next anonymous pass. The same
                    // applies to the dismissal path: the user opted out of
                    // paying and must now create an account before reaching
                    // MainTabView. The other AuthView call sites (LandingView
                    // Create Account / Sign In, and the unauthenticated/login
                    // routing branch) keep the default `canGoBack: true`.
                    } else {
                        let _ = log("🎯 RootView: Anonymous user - requiring account creation")
                        NavigationStack {
                            AuthView(mode: .signup, canGoBack: false)
                        }
                    }

                // MARK: - Unauthenticated User Flow
                } else if authManager.hasCompletedOnboarding {
                    let _ = log("🎯 RootView: User NOT authenticated, but HAS seen onboarding")
                    NavigationStack {
                        AuthView(mode: .login)
                    }

                } else {
                    let _ = log("🎯 RootView: User NOT authenticated, showing Landing")
                    LandingView()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
            .animation(.easeInOut(duration: 0.3), value: authManager.isCheckingSession)
            .animation(.easeInOut(duration: 0.3), value: authManager.isAnonymousUser)
            .animation(.easeInOut(duration: 0.3), value: authManager.hasActiveSubscription)
        }
        .task {
            // Step 1: Configure RevenueCat on app launch (MUST be first)
            RevenueCatManager.shared.configure()

            // Step 1b: PostHog analytics. Runs on a detached background task
            // so SDK setup and /decide response processing don't compete with
            // the main thread during OnboardingView's first render — this is
            // the fix for the launch-time onboarding lag we previously
            // diagnosed. Every event carries an `environment` super-property
            // so dashboards can filter dev/simulator traffic out of prod
            // metrics (filter `environment = "prod"` on all insights).
            //
            // For anonymous users, identify with the persisted anonymous ID
            // up-front so onboarding events have a stable distinct_id. The
            // `isAuthed` snapshot is captured here on main; if the user is
            // authed, AuthManager.observeAuthState() handles identify(uuid)
            // separately when .initialSession / .signedIn fires.
            let isAuthedAtLaunch = authManager.isAuthenticated
            let anonymousId = AnonymousUserManager.shared.anonymousUserId
            Task.detached(priority: .utility) {
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
                // PostHogSDK.screen() call behind the .postHogScreenView()
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

                #if DEBUG
                PostHogSDK.shared.register(["environment": "dev"])
                #else
                PostHogSDK.shared.register(["environment": "prod"])
                #endif

                if !isAuthedAtLaunch {
                    PostHogSDK.shared.identify(anonymousId)
                }
            }

            // Step 2: Initialize subscription monitoring (after RevenueCat is ready)
            SubscriptionManager.shared.initializeMonitoring()
            authManager.setupSubscriptionMonitoring()
            
            // Step 3: Clear any existing notification badge on app launch
            NotificationManager.shared.clearNotificationBadgeAndDelivered()
            
            // Step 4: Restore session gracefully on app launch
            await authManager.restoreSessionGracefully()

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
