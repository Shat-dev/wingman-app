//
//  SplashView.swift
//  Wingman
//
//  Created by Adnan Khan on 29/11/2025.
//
import SwiftUI

struct SplashView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var networkMonitor = NetworkMonitor.shared
    
    @State private var showLanding = false

    var body: some View {
        if showLanding {
            LandingView()
                .transition(.opacity)
        } else {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Spacer()
                    
                    // App Logo - always fully visible
                    Image("wingman_logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 200)
                    
                    // Loading indicator while checking session
//                    if authManager.isCheckingSession {
//                        ProgressView()
//                            .progressViewStyle(CircularProgressViewStyle(tint: .wingmanBlack))
//                            .scaleEffect(1.2)
//                            .transition(.opacity)
//                    }
//                    
                    Spacer()
                    
                    // Offline banner at bottom
                    if !networkMonitor.isConnected {
                        OfflineBannerView()
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .padding(.bottom, 40)
                    }
                }
            }
            .onAppear {
                // Wait for session check to complete, then transition if needed
                Task {
                    // Wait for session check to finish
                    while authManager.isCheckingSession {
                        try? await Task.sleep(nanoseconds: 100_000_000) // Check every 0.1 second
                    }

                    // Only show landing if not authenticated
                    if !authManager.isAuthenticated {
                        await MainActor.run {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showLanding = true
                            }
                        }
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: networkMonitor.isConnected)
            .animation(.easeInOut(duration: 0.3), value: authManager.isCheckingSession)
        }
    }
}

// MARK: - Offline Banner Component
struct OfflineBannerView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 14, weight: .medium))
            
            Text("No internet connection")
                .font(.manropeRegular(size: 14))
        }
        .foregroundColor(.orange)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.orange.opacity(0.12))
        )
    }
}

#Preview {
    SplashView()
        .environmentObject(AuthManager())
}
