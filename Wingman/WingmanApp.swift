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
            // LINE 19-38: NAVIGATION LOGIC BASED ON AUTH STATE
            if authManager.isAuthenticated {
                let _ = print("🎯 RootView: User IS authenticated")
                
                // User is logged in
                if authManager.hasCompletedQuestions {
                    let _ = print("🎯 RootView: Showing DashboardView (questions completed)")
                    // User has completed questions -> Show Dashboard
                    DashboardView()
                } else {
                    let _ = print("🎯 RootView: Showing OnboardingView (questions NOT completed)")
                    // User hasn't completed questions -> Show Onboarding Questions
                    NavigationStack {
                        OnboardingView()
                    }
                }
            } else if authManager.hasCompletedOnboarding {
                let _ = print("🎯 RootView: User NOT authenticated, but HAS seen onboarding")
                // User has seen landing but not logged in -> Show Login screen
                NavigationStack {
                    AuthView(mode: .login)
                }
            } else {
                let _ = print("🎯 RootView: User NOT authenticated, HASN'T seen onboarding")
                // First time user -> Show Splash + Landing
                SplashView()
            }
        }
        .onChange(of: authManager.isAuthenticated) { newValue in
            print("\n🔔 RootView detected isAuthenticated change: \(newValue)")
            print("   - hasCompletedQuestions: \(authManager.hasCompletedQuestions)")
            print("   - hasCompletedOnboarding: \(authManager.hasCompletedOnboarding)")
        }
        .onChange(of: authManager.hasCompletedQuestions) { newValue in
            print("\n🔔 RootView detected hasCompletedQuestions change: \(newValue)")
        }
    }
}
