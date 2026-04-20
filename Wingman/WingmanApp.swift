//
//  WingmanApp.swift
//  Wingman
//
//  Created by Adnan Khan on 29/11/2025.
//

import SwiftUI
import GoogleSignIn
import UserNotifications
import RevenueCat
import RevenueCatUI
import BackgroundTasks

@main
struct WingmanApp: App {
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .preferredColorScheme(.light) // Force Light Mode
                .onOpenURL { url in
                    // Handle Google Sign-In callback URL
                    GIDSignIn.sharedInstance.handle(url)
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
                    //    show RatingPromptView. Gated on `!hasCompletedPaywallFlow`
                    //    so existing paying users (who already passed the
                    //    paywall) never route back here after the update —
                    //    they go straight to MainTabView below.
                    } else if !authManager.hasCompletedPaywallFlow && !authManager.hasSeenRatingPrompt {
                        let _ = log("🎯 RootView: Showing RatingPromptView (rating prompt NOT seen)")
                        NavigationStack {
                            RatingPromptView()
                        }

                    // ✅ 3) Questions + rating ack'd → show Paywall (and Referral flow)
                    } else if !authManager.hasCompletedPaywallFlow {
                        let _ = log("🎯 RootView: Showing PaywallView (paywall flow NOT completed)")
                        NavigationStack {
                            PaywallView(authManager: authManager, isDismissible: true)
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
                    //    `!hasCompletedPaywallFlow` for parity with the
                    //    authenticated flow.
                    if !authManager.hasCompletedPaywallFlow && !authManager.hasSeenRatingPrompt {
                        let _ = log("🎯 RootView: Anonymous user - showing RatingPromptView")
                        NavigationStack {
                            RatingPromptView()
                        }

                    // ✅ Anonymous user - questions + rating ack'd → show Paywall
                    } else if !authManager.hasCompletedPaywallFlow {
                        let _ = log("🎯 RootView: Anonymous user - showing PaywallView")
                        NavigationStack {
                            PaywallView(authManager: authManager, isDismissible: true)
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
            
            // Set RevenueCat user ID when user authenticates
            if newValue, let userId = SupabaseManager.shared.currentUserId {
                RevenueCatManager.shared.setUserID(userId)
            } else if !newValue {
                RevenueCatManager.shared.logoutUser()
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
