//
//  WingmanApp.swift
//  Wingman
//
//  Created by Adnan Khan on 29/11/2025.
//

import SwiftUI

@main
struct WingmanApp: App {
    @StateObject private var authManager = AuthManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        Group {
            if authManager.isAuthenticated {
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

            } else if authManager.hasCompletedOnboarding {
                let _ = print("🎯 RootView: User NOT authenticated, but HAS seen onboarding")
                NavigationStack {
                    AuthView(mode: .login)
                }

            } else {
                let _ = print("🎯 RootView: User NOT authenticated, HASN'T seen onboarding")
                SplashView()
            }
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
