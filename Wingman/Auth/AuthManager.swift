//
//  AuthManager.swift
//  Wingman
//
//  Created by Adnan Khan on 15/12/2025.
//


import Foundation
import Combine
import Supabase
import Auth

@MainActor
final class AuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var hasCompletedOnboarding: Bool = false
    @Published var currentUser: User?
    
    private let client = SupabaseManager.shared.client
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        // Check if user has completed onboarding
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
        // Listen to auth state changes
        Task {
            await observeAuthState()
        }
    }
    
    private func observeAuthState() async {
        for await (event, session) in client.auth.authStateChanges {
            switch event {
            case .signedIn:
                if let session = session {
                    self.isAuthenticated = true
                    self.currentUser = session.user
                    print("✅ User signed in: \(session.user.email ?? "unknown")")
                }
                
            case .signedOut:
                self.isAuthenticated = false
                self.currentUser = nil
                print("🚪 User signed out")
                
            case .initialSession:
                if let session = session {
                    self.isAuthenticated = true
                    self.currentUser = session.user
                    print("✅ Initial session found: \(session.user.email ?? "unknown")")
                } else {
                    self.isAuthenticated = false
                    print("❌ No initial session")
                }
                
            case .tokenRefreshed:
                if let session = session {
                    self.currentUser = session.user
                    print("🔄 Token refreshed")
                }
                
            case .userUpdated:
                if let session = session {
                    self.currentUser = session.user
                    print("👤 User updated")
                }
                
            case .passwordRecovery:
                print("🔑 Password recovery initiated")
                
            case .userDeleted:
                self.isAuthenticated = false
                self.currentUser = nil
                print("🗑️ User deleted")
                
            @unknown default:
                print("⚠️ Unknown auth event")
            }
        }
    }
    
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
    
    func skipOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
    
    func signOut() async {
        do {
            try await client.auth.signOut()
            isAuthenticated = false
            currentUser = nil
        } catch {
            print("❌ Sign out error: \(error.localizedDescription)")
        }
    }
    
    func resetOnboarding() {
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }
}
