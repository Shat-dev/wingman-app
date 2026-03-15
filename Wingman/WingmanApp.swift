//
//  WingmanApp.swift
//  Wingman
//
//  Created by Adnan Khan on 29/11/2025.
//

import SwiftUI
import GoogleSignIn
import UserNotifications

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
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Clear notification badge when app becomes active
                    clearNotificationBadge()
                }
        }
    }
    
    // MARK: - Clear Notification Badge
    private func clearNotificationBadge() {
        print("🔔 App became active - clearing notification badge")
        NotificationManager.shared.clearNotificationBadgeAndDelivered()
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
                    let _ = print("🎯 RootView: Checking session...")
                    SplashView()
                    
                // MARK: - Authenticated User Flow
                } else if authManager.isAuthenticated {
                    let _ = print("🎯 RootView: User IS authenticated")

                    // ✅ 1) Onboarding questions not finished
                    if !authManager.hasCompletedQuestions {
                        let _ = print("🎯 RootView: Showing OnboardingView (questions NOT completed)")
                        NavigationStack {
                            OnboardingView()
                        }

                    // ✅ 2) Questions finished → show Paywall (and Referral flow)
                    } else if !authManager.hasCompletedPaywallFlow {
                        let _ = print("🎯 RootView: Showing PaywallView (paywall flow NOT completed)")
                        NavigationStack {
                            PaywallView()
                        }

                    // ✅ 3) Paywall + Referral finished → MainTabView (Home)
                    } else {
                        let _ = print("🎯 RootView: Showing MainTabView (paywall flow completed)")
                        MainTabView()
                    }
                
                // MARK: - Anonymous User Flow (Skip for now)
                } else if authManager.isAnonymousUser && authManager.hasCompletedOnboarding {
                    let _ = print("🎯 RootView: Anonymous user completed onboarding")
                    
                    // ✅ Anonymous user - questions finished → show Paywall
                    if !authManager.hasCompletedPaywallFlow {
                        let _ = print("🎯 RootView: Anonymous user - showing PaywallView")
                        NavigationStack {
                            PaywallView()
                        }
                    
                    // ✅ Anonymous user - paywall finished → require account creation
                    } else {
                        let _ = print("🎯 RootView: Anonymous user - requiring account creation")
                        NavigationStack {
                            AuthView(mode: .signup)
                        }
                    }

                // MARK: - Unauthenticated User Flow
                } else if authManager.hasCompletedOnboarding {
                    let _ = print("🎯 RootView: User NOT authenticated, but HAS seen onboarding")
                    NavigationStack {
                        AuthView(mode: .login)
                    }

                } else {
                    let _ = print("🎯 RootView: User NOT authenticated, showing Landing")
                    LandingView()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: authManager.isAuthenticated)
            .animation(.easeInOut(duration: 0.3), value: authManager.isCheckingSession)
            .animation(.easeInOut(duration: 0.3), value: authManager.isAnonymousUser)
        }
        .task {
            // Clear any existing notification badge on app launch
            NotificationManager.shared.clearNotificationBadgeAndDelivered()
            
            // Restore session gracefully on app launch
            await authManager.restoreSessionGracefully()
            
            // Setup notifications on app launch
            NotificationManager.shared.setupNotificationsOnLaunch()
        }
        .onChange(of: authManager.isAuthenticated) { newValue in
            print("\n🔔 RootView detected isAuthenticated change: \(newValue)")
            print("   - hasCompletedQuestions: \(authManager.hasCompletedQuestions)")
            print("   - hasCompletedPaywallFlow: \(authManager.hasCompletedPaywallFlow)")
            print("   - hasCompletedOnboarding: \(authManager.hasCompletedOnboarding)")
        }
        .onChange(of: authManager.hasCompletedQuestions) { newValue in
            print("\n🔔 RootView detected hasCompletedQuestions change: \(newValue)")
        }
        .onChange(of: authManager.hasCompletedPaywallFlow) { newValue in
            print("\n🔔 RootView detected hasCompletedPaywallFlow change: \(newValue)")
        }
    }
}
