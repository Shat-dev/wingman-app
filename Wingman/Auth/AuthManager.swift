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
import GoogleSignIn
import AuthenticationServices
import CryptoKit

@MainActor
final class AuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false {
        didSet {
            print("🔐 isAuthenticated changed: \(oldValue) → \(isAuthenticated)")
        }
    }
    
    // MARK: - Session Checking State
    @Published var isCheckingSession: Bool = true {
        didSet {
            print("🔍 isCheckingSession changed: \(oldValue) → \(isCheckingSession)")
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

    // ✅ NEW: Paywall + Referral flow completion
    @Published var hasCompletedPaywallFlow: Bool = false {
        didSet {
            print("💳 hasCompletedPaywallFlow changed: \(oldValue) → \(hasCompletedPaywallFlow)")
        }
    }

    @Published var currentUser: User? {
        didSet {
            print("👤 currentUser changed: \(oldValue?.email ?? "nil") → \(currentUser?.email ?? "nil")")
        }
    }
    
    @Published var isGoogleSignInLoading: Bool = false
    @Published var googleSignInError: String?
    
    @Published var isAppleSignInLoading: Bool = false
    @Published var appleSignInError: String?
    
    // Store the nonce for Apple Sign-In verification
    private var currentNonce: String?

    private let client = SupabaseManager.shared.client
    private var cancellables = Set<AnyCancellable>()
    
    // Google OAuth Client ID
    private let googleClientID = "915810938432-fh9l3u8icl6vcksn2j841c5nbljfh824.apps.googleusercontent.com"

    init() {
        print("\n🏁 ========== AuthManager INIT ==========")

        // Check if user has completed onboarding (seen landing pages)
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        print("📋 Loaded hasCompletedOnboarding: \(hasCompletedOnboarding)")

        // This global key might not be used in your current per-user storage,
        // but keeping it doesn't hurt; the real value loads after session.
        hasCompletedQuestions = UserDefaults.standard.bool(forKey: "hasCompletedQuestions")
        print("❓ Loaded hasCompletedQuestions: \(hasCompletedQuestions)")

        // Same note: actual per-user value loads after session
        hasCompletedPaywallFlow = UserDefaults.standard.bool(forKey: "hasCompletedPaywallFlow")
        print("💳 Loaded hasCompletedPaywallFlow: \(hasCompletedPaywallFlow)")

        // Listen to auth state changes
        Task {
            print("🎧 Starting to observe auth state changes...")
            await observeAuthState()
        }
    }

    // AUTH STATE OBSERVER - THIS HANDLES AUTOMATIC NAVIGATION
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

                    // ✅ Persist email immediately
                    if let email = session.user.email, !email.isEmpty {
                        UserDefaults.standard.set(email, forKey: "user_email")
                        print("📩 Saved user_email on sign-in: \(email)")
                    }

                    // ✅ Load user state
                    await checkUserQuestionStatus(userId: session.user.id.uuidString)
                    await checkUserPaywallFlowStatus(userId: session.user.id.uuidString)

                    print("✅ User signed in: \(session.user.email ?? "unknown")")
                    print("🎯 Auth state updated - RootView should now react")
                }

            case .signedOut:
                print("🚪 Event type: SIGNED_OUT")
                self.isAuthenticated = false
                self.currentUser = nil
                self.hasCompletedQuestions = false
                self.hasCompletedPaywallFlow = false
                print("🚪 User signed out")

            case .initialSession:
                print("🔵 Event type: INITIAL_SESSION")
                if let session = session {
                    self.isAuthenticated = true
                    self.currentUser = session.user

                    // ✅ Persist email on initial session
                    if let email = session.user.email, !email.isEmpty {
                        UserDefaults.standard.set(email, forKey: "user_email")
                        print("📩 Saved user_email on initial session: \(email)")
                    }

                    // ✅ Load user state
                    await checkUserQuestionStatus(userId: session.user.id.uuidString)
                    await checkUserPaywallFlowStatus(userId: session.user.id.uuidString)

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
                    // Email generally doesn’t change, but this keeps it fresh
                    if let email = session.user.email, !email.isEmpty {
                        UserDefaults.standard.set(email, forKey: "user_email")
                        print("📩 Saved user_email on user update: \(email)")
                    }
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
                self.hasCompletedPaywallFlow = false
                print("🗑️ User deleted")

            @unknown default:
                print("⚠️ Event type: UNKNOWN")
                print("⚠️ Unknown auth event")
            }

            print("========================================\n")
        }
    }

    // MARK: - Per-user status loads
    private func checkUserQuestionStatus(userId: String) async {
        let key = "hasCompletedQuestions_\(userId)"
        hasCompletedQuestions = UserDefaults.standard.bool(forKey: key)
        print("📋 User question status loaded: \(hasCompletedQuestions) for user: \(userId)")
    }

    private func checkUserPaywallFlowStatus(userId: String) async {
        let key = "hasCompletedPaywallFlow_\(userId)"
        hasCompletedPaywallFlow = UserDefaults.standard.bool(forKey: key)
        print("💳 Paywall flow status loaded: \(hasCompletedPaywallFlow) for user: \(userId)")
    }
    
    // MARK: - Graceful Session Restoration (Offline-First)
    
    /// Restores session from local cache instantly, then validates with server in background
    func restoreSessionGracefully() async {
        print("\n🔄 ========== GRACEFUL SESSION RESTORE ==========")
        
        do {
            // Step 1: Try to get cached session instantly (no network required)
            let session = try await client.auth.session
            
            print("✅ Cached session found!")
            print("   - User ID: \(session.user.id)")
            print("   - Email: \(session.user.email ?? "nil")")
            
            // Immediately set authenticated state from cache
            self.currentUser = session.user
            self.isAuthenticated = true
            
            // Load user-specific states
            await checkUserQuestionStatus(userId: session.user.id.uuidString)
            await checkUserPaywallFlowStatus(userId: session.user.id.uuidString)
            
            // Mark session check complete - UI can now render
            self.isCheckingSession = false
            print("✅ Session restored from cache - UI ready")
            
            // Step 2: Validate session with server in background (non-blocking)
            Task {
                await validateSessionInBackground()
            }
            
        } catch {
            print("❌ No cached session found: \(error.localizedDescription)")
            
            // No session - user needs to log in
            self.isAuthenticated = false
            self.currentUser = nil
            self.isCheckingSession = false
            print("ℹ️ No session - showing login screen")
        }
        
        print("================================================\n")
    }
    
    /// Validates session with server in background, only signs out if truly invalid
    private func validateSessionInBackground() async {
        print("🔄 Background: Validating session with server...")
        
        do {
            // Try to refresh the session token
            let session = try await client.auth.refreshSession()
            print("✅ Background: Session validated successfully")
            print("   - Token refreshed for: \(session.user.email ?? "unknown")")
            
        } catch {
            print("⚠️ Background: Session validation failed: \(error.localizedDescription)")
            
            // Only sign out if it's a real auth error, not a network error
            if isNetworkError(error) {
                print("📶 Background: Network error detected - keeping cached session")
                // Don't sign out, user might just be offline
            } else if isAuthenticationError(error) {
                print("🔐 Background: Auth error detected - session is invalid")
                // Token is truly invalid, sign out gracefully
                await signOut()
            } else {
                print("❓ Background: Unknown error - keeping cached session for safety")
            }
        }
    }
    
    // MARK: - Error Detection Helpers
    
    /// Checks if an error is a network-related error (offline, timeout, etc.)
    private func isNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        
        // Check for common network error domains and codes
        if nsError.domain == NSURLErrorDomain {
            let networkErrorCodes: [Int] = [
                NSURLErrorNotConnectedToInternet,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorTimedOut,
                NSURLErrorCannotConnectToHost,
                NSURLErrorCannotFindHost,
                NSURLErrorDNSLookupFailed,
                NSURLErrorDataNotAllowed,
                NSURLErrorInternationalRoamingOff
            ]
            return networkErrorCodes.contains(nsError.code)
        }
        
        // Check error description for network-related keywords
        let errorDescription = error.localizedDescription.lowercased()
        let networkKeywords = ["network", "internet", "offline", "connection", "timeout", "unreachable"]
        return networkKeywords.contains { errorDescription.contains($0) }
    }
    
    /// Checks if an error is an authentication error (invalid token, expired session, etc.)
    private func isAuthenticationError(_ error: Error) -> Bool {
        let errorDescription = error.localizedDescription.lowercased()
        let authKeywords = ["unauthorized", "401", "invalid", "expired", "token", "authentication", "forbidden", "403"]
        return authKeywords.contains { errorDescription.contains($0) }
    }

    // MARK: - Onboarding
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

    // MARK: - Questions
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

    // MARK: - Paywall Flow (Paywall + Referral)
    func completePaywallFlow() {
        print("✅ completePaywallFlow() called")
        hasCompletedPaywallFlow = true

        if let userId = currentUser?.id.uuidString {
            let key = "hasCompletedPaywallFlow_\(userId)"
            UserDefaults.standard.set(true, forKey: key)
            print("✅ Paywall flow completed for user: \(userId)")
        }
    }

    // MARK: - Google Sign-In
    func signInWithGoogle() async {
        print("\n🔵 signInWithGoogle() called")
        
        isGoogleSignInLoading = true
        googleSignInError = nil
        
        do {
            // Get the root view controller for presenting Google Sign-In
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                throw GoogleSignInError.noRootViewController
            }
            
            // Configure Google Sign-In
            let config = GIDConfiguration(clientID: googleClientID)
            GIDSignIn.sharedInstance.configuration = config
            
            // Perform Google Sign-In
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            guard let idToken = result.user.idToken?.tokenString else {
                throw GoogleSignInError.noIdToken
            }
            
            let accessToken = result.user.accessToken.tokenString
            
            print("✅ Google Sign-In successful")
            print("   - User: \(result.user.profile?.email ?? "unknown")")
            print("   - ID Token obtained: \(idToken.prefix(20))...")
            
            // Sign in to Supabase with the Google ID token
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken,
                    accessToken: accessToken
                )
            )
            
            print("✅ Supabase sign-in successful")
            print("   - User ID: \(session.user.id)")
            print("   - Email: \(session.user.email ?? "nil")")
            
            // Mark onboarding as complete since user used social login
            completeOnboarding()
            
            isGoogleSignInLoading = false
            
        } catch let error as GIDSignInError {
            isGoogleSignInLoading = false
            
            // Handle user cancellation gracefully
            if error.code == .canceled {
                print("ℹ️ Google Sign-In cancelled by user")
                googleSignInError = nil
            } else {
                print("❌ Google Sign-In error: \(error.localizedDescription)")
                googleSignInError = error.localizedDescription
            }
            
        } catch let error as GoogleSignInError {
            isGoogleSignInLoading = false
            print("❌ Google Sign-In error: \(error.localizedDescription)")
            googleSignInError = error.localizedDescription
            
        } catch {
            isGoogleSignInLoading = false
            print("❌ Supabase sign-in error: \(error.localizedDescription)")
            googleSignInError = "Sign-in failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Apple Sign-In
    func signInWithApple() {
        print("\n🍎 signInWithApple() called")
        
        isAppleSignInLoading = true
        appleSignInError = nil
        
        // Generate a random nonce for security
        let nonce = randomNonceString()
        currentNonce = nonce
        
        // Create Apple ID request
        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = sha256(nonce)
        
        // Create and present the authorization controller
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AppleSignInDelegate(authManager: self)
        
        // Store delegate to prevent deallocation
        appleSignInDelegate = delegate
        
        authorizationController.delegate = delegate
        authorizationController.presentationContextProvider = delegate
        authorizationController.performRequests()
    }
    
    // Store delegate reference to prevent deallocation
    private var appleSignInDelegate: AppleSignInDelegate?
    
    // Called by AppleSignInDelegate when authorization succeeds
    func handleAppleSignInSuccess(idToken: String, fullName: PersonNameComponents?) async {
        print("✅ Apple Sign-In successful, signing in with Supabase...")
        
        do {
            guard let nonce = currentNonce else {
                throw AppleSignInError.noNonce
            }
            
            // Sign in to Supabase with the Apple ID token
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken,
                    nonce: nonce
                )
            )
            
            print("✅ Supabase Apple sign-in successful")
            print("   - User ID: \(session.user.id)")
            print("   - Email: \(session.user.email ?? "nil")")
            
            // If we got the full name (first sign-in only), save it to user metadata
            if let fullName = fullName {
                let displayName = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                
                if !displayName.isEmpty {
                    print("📝 Saving display name: \(displayName)")
                    
                    // Update user metadata with the name
                    _ = try await client.auth.update(user: UserAttributes(
                        data: [
                            "display_name": .string(displayName),
                            "full_name": .string(displayName)
                        ]
                    ))
                    
                    // Also save to UserDefaults for quick access
                    UserDefaults.standard.set(displayName, forKey: "user_name")
                }
            }
            
            // Mark onboarding as complete since user used social login
            completeOnboarding()
            
            isAppleSignInLoading = false
            currentNonce = nil
            appleSignInDelegate = nil
            
        } catch {
            isAppleSignInLoading = false
            currentNonce = nil
            appleSignInDelegate = nil
            print("❌ Supabase Apple sign-in error: \(error.localizedDescription)")
            appleSignInError = "Sign-in failed: \(error.localizedDescription)"
        }
    }
    
    // Called by AppleSignInDelegate when authorization fails
    func handleAppleSignInFailure(error: Error) {
        isAppleSignInLoading = false
        currentNonce = nil
        appleSignInDelegate = nil
        
        // Check if user cancelled
        if let authError = error as? ASAuthorizationError {
            switch authError.code {
            case .canceled:
                print("ℹ️ Apple Sign-In cancelled by user")
                appleSignInError = nil
                return
            case .failed:
                print("❌ Apple Sign-In failed")
                appleSignInError = "Sign-in failed. Please try again."
            case .invalidResponse:
                print("❌ Apple Sign-In invalid response")
                appleSignInError = "Invalid response from Apple. Please try again."
            case .notHandled:
                print("❌ Apple Sign-In not handled")
                appleSignInError = "Sign-in was not handled. Please try again."
            case .notInteractive:
                print("❌ Apple Sign-In not interactive")
                appleSignInError = "Sign-in requires user interaction."
            case .unknown:
                print("❌ Apple Sign-In unknown error")
                appleSignInError = "An unknown error occurred. Please try again."
            @unknown default:
                print("❌ Apple Sign-In unknown error code")
                appleSignInError = error.localizedDescription
            }
        } else {
            print("❌ Apple Sign-In error: \(error.localizedDescription)")
            appleSignInError = error.localizedDescription
        }
    }
    
    // MARK: - Nonce Generation Helpers
    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)")
        }
        
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        let nonce = randomBytes.map { byte in
            charset[Int(byte) % charset.count]
        }
        return String(nonce)
    }
    
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashedData = SHA256.hash(data: inputData)
        let hashString = hashedData.compactMap {
            String(format: "%02x", $0)
        }.joined()
        return hashString
    }

    // MARK: - Sign out / Reset
    func signOut() async {
        print("\n🚪 signOut() called")
        do {
            try await client.auth.signOut()
            isAuthenticated = false
            currentUser = nil
            hasCompletedQuestions = false
            hasCompletedPaywallFlow = false
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

    func resetPaywallFlow() {
        print("🔄 resetPaywallFlow() called")
        hasCompletedPaywallFlow = false
        if let userId = currentUser?.id.uuidString {
            let key = "hasCompletedPaywallFlow_\(userId)"
            UserDefaults.standard.set(false, forKey: key)
            print("🔄 Paywall flow reset for user: \(userId)")
        }
    }
}

// MARK: - Google Sign-In Errors
enum GoogleSignInError: LocalizedError {
    case noRootViewController
    case noIdToken
    case signInFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .noRootViewController:
            return "Unable to find root view controller"
        case .noIdToken:
            return "Unable to get ID token from Google"
        case .signInFailed(let message):
            return "Sign-in failed: \(message)"
        }
    }
}

// MARK: - Apple Sign-In Errors
enum AppleSignInError: LocalizedError {
    case noNonce
    case noIdentityToken
    case invalidIdentityToken
    case noAuthorizationCode
    
    var errorDescription: String? {
        switch self {
        case .noNonce:
            return "Invalid state: A nonce was not generated"
        case .noIdentityToken:
            return "Unable to get identity token from Apple"
        case .invalidIdentityToken:
            return "Unable to serialize identity token"
        case .noAuthorizationCode:
            return "Unable to get authorization code from Apple"
        }
    }
}

// MARK: - Apple Sign-In Delegate
class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    
    private weak var authManager: AuthManager?
    
    init(authManager: AuthManager) {
        self.authManager = authManager
        super.init()
    }
    
    // MARK: - ASAuthorizationControllerPresentationContextProviding
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window found")
        }
        return window
    }
    
    // MARK: - ASAuthorizationControllerDelegate
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("❌ Invalid credential type")
            Task { @MainActor in
                authManager?.handleAppleSignInFailure(error: AppleSignInError.noIdentityToken)
            }
            return
        }
        
        guard let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            print("❌ Unable to get identity token")
            Task { @MainActor in
                authManager?.handleAppleSignInFailure(error: AppleSignInError.noIdentityToken)
            }
            return
        }
        
        print("✅ Apple authorization successful")
        print("   - User ID: \(appleIDCredential.user)")
        print("   - Email: \(appleIDCredential.email ?? "not provided")")
        print("   - Full Name: \(appleIDCredential.fullName?.givenName ?? "not provided") \(appleIDCredential.fullName?.familyName ?? "")")
        
        // Pass the token and name to AuthManager
        Task { @MainActor in
            await authManager?.handleAppleSignInSuccess(
                idToken: identityToken,
                fullName: appleIDCredential.fullName
            )
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("❌ Apple authorization failed: \(error.localizedDescription)")
        Task { @MainActor in
            authManager?.handleAppleSignInFailure(error: error)
        }
    }
}
