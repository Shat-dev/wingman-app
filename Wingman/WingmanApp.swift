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
                // User is logged in -> Show Dashboard
                DashboardView()
            } else if authManager.hasCompletedOnboarding {
                // User has seen onboarding but not logged in -> Show Auth directly
                NavigationStack {
                    AuthView(mode: .signup)
                }
            } else {
                // First time user -> Show Onboarding
                SplashView()
            }
        }
    }
}
