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
    @Published var isAuthenticated: Bool = false {
        didSet {
            print("🔐 isAuthenticated changed: \(oldValue) → \(isAuthenticated)")
        }
    }
    
    @Published var hasCompletedOnboarding: Bool = false {
        didSet {
            print("📋 hasCompletedOnboarding changed: \(oldValue) → \(hasCompletedOnboarding)")
        }
    }
    
    @Published var hasCompletedQuestions: Bool = false {
        didSet {
            print("❓ hasCompletedQuestions changed: \(oldValue) → \(hasCompletedQuestions)")
        }
    }
    
    @Published var currentUser: User? {
        didSet {
            print("👤 currentUser changed: \(oldValue?.email ?? "nil") → \(currentUser?.email ?? "nil")")
        }
    }
    
    private let client = SupabaseManager.shared.client
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        print("\n🏁 ========== AuthManager INIT ==========")
        
        // Check if user has completed onboarding (seen landing pages)
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        print("📋 Loaded hasCompletedOnboarding: \(hasCompletedOnboarding)")
        
        // Check if user has completed questions
        hasCompletedQuestions = UserDefaults.standard.bool(forKey: "hasCompletedQuestions")
        print("❓ Loaded hasCompletedQuestions: \(hasCompletedQuestions)")
        
        // Listen to auth state changes
        Task {
            print("🎧 Starting to observe auth state changes...")
            await observeAuthState()
        }
    }
    
    // LINE 56-115: AUTH STATE OBSERVER - THIS HANDLES AUTOMATIC NAVIGATION
    private func observeAuthState() async {
        print("\n🔄 observeAuthState() started")
        
        for await (event, session) in client.auth.authStateChanges {
            print("\n⚡️ ========== AUTH EVENT RECEIVED ==========")
            print("📡 Event: \(event)")
            print("🔑 Session exists: \(session != nil)")
            
            if let session = session {
                print("   - User ID: \(session.user.id)")
                print("   - Email: \(session.user.email ?? "nil")")
                print("   - Created at: \(session.user.createdAt)")
            }
            
            switch event {
            case .signedIn:
                print("✅ Event type: SIGNED_IN")
                if let session = session {
                    self.isAuthenticated = true
                    self.currentUser = session.user
                    UserDefaults.standard.set(session.user.id.uuidString, forKey: "current_user_id")
                    // Load user's question completion status from UserDefaults or Supabase
                    await checkUserQuestionStatus(userId: session.user.id.uuidString)
                    
                    print("✅ User signed in: \(session.user.email ?? "unknown")")
                    print("🎯 Auth state updated - RootView should now react")
                }
                
            case .signedOut:
                print("🚪 Event type: SIGNED_OUT")
                self.isAuthenticated = false
                self.currentUser = nil
                self.hasCompletedQuestions = false
                print("🚪 User signed out")
                
            case .initialSession:
                print("🔵 Event type: INITIAL_SESSION")
                if let session = session {
                    self.isAuthenticated = true
                    self.currentUser = session.user
                    
                    // Load user's question completion status
                    await checkUserQuestionStatus(userId: session.user.id.uuidString)
                    
                    print("✅ Initial session found: \(session.user.email ?? "unknown")")
                } else {
                    self.isAuthenticated = false
                    print("❌ No initial session")
                }
                
            case .tokenRefreshed:
                print("🔄 Event type: TOKEN_REFRESHED")
                if let session = session {
                    self.currentUser = session.user
                    print("🔄 Token refreshed")
                }
                
            case .userUpdated:
                print("👤 Event type: USER_UPDATED")
                if let session = session {
                    self.currentUser = session.user
                    print("👤 User updated")
                }
                
            case .passwordRecovery:
                print("🔑 Event type: PASSWORD_RECOVERY")
                print("🔑 Password recovery initiated")
                
            case .userDeleted:
                print("🗑️ Event type: USER_DELETED")
                self.isAuthenticated = false
                self.currentUser = nil
                self.hasCompletedQuestions = false
                print("🗑️ User deleted")
                
            @unknown default:
                print("⚠️ Event type: UNKNOWN")
                print("⚠️ Unknown auth event")
            }
            
            print("========================================\n")
        }
    }
    
    // Check if user has completed questions from UserDefaults
    private func checkUserQuestionStatus(userId: String) async {
        let key = "hasCompletedQuestions_\(userId)"
        hasCompletedQuestions = UserDefaults.standard.bool(forKey: key)
        print("📋 User question status loaded: \(hasCompletedQuestions) for user: \(userId)")
    }
    
    func completeOnboarding() {
        print("✅ completeOnboarding() called")
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
    
    func skipOnboarding() {
        print("⏭️ skipOnboarding() called")
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
    
    func completeQuestions() {
        print("✅ completeQuestions() called")
        hasCompletedQuestions = true
        
        // Save per user
        if let userId = currentUser?.id.uuidString {
            let key = "hasCompletedQuestions_\(userId)"
            UserDefaults.standard.set(true, forKey: key)
            print("✅ Questions completed for user: \(userId)")
        }
    }
    
    func signOut() async {
        print("\n🚪 signOut() called")
        do {
            try await client.auth.signOut()
            isAuthenticated = false
            currentUser = nil
            hasCompletedQuestions = false
            print("✅ Sign out successful")
        } catch {
            print("❌ Sign out error: \(error.localizedDescription)")
        }
    }
    
    func resetOnboarding() {
        print("🔄 resetOnboarding() called")
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }
    
    func resetQuestions() {
        print("🔄 resetQuestions() called")
        hasCompletedQuestions = false
        if let userId = currentUser?.id.uuidString {
            let key = "hasCompletedQuestions_\(userId)"
            UserDefaults.standard.set(false, forKey: key)
            print("🔄 Questions reset for user: \(userId)")
        }
    }
}
