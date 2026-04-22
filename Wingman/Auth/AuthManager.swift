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
import RevenueCat
import StoreKit

@MainActor
final class AuthManager: ObservableObject {
    @Published var isAuthenticated: Bool = false {
        didSet {
            log("🔐 isAuthenticated changed: \(oldValue) → \(isAuthenticated)")
        }
    }
    
    // MARK: - Session Checking State
    @Published var isCheckingSession: Bool = true {
        didSet {
            log("🔍 isCheckingSession changed: \(oldValue) → \(isCheckingSession)")
        }
    }

    @Published var hasCompletedOnboarding: Bool = false {
        didSet {
            log("📋 hasCompletedOnboarding changed: \(oldValue) → \(hasCompletedOnboarding)")
        }
    }

    @Published var hasCompletedQuestions: Bool = false {
        didSet {
            log("❓ hasCompletedQuestions changed: \(oldValue) → \(hasCompletedQuestions)")
        }
    }

    // ✅ NEW: Paywall + Referral flow completion
    @Published var hasCompletedPaywallFlow: Bool = false {
        didSet {
            log("💳 hasCompletedPaywallFlow changed: \(oldValue) → \(hasCompletedPaywallFlow)")
        }
    }

    // Rating prompt (shown between onboarding questions and paywall).
    // Per-onboarding-pass gate: flipped to true on Continue so the user can
    // advance to the paywall, then reset on signOut / account deletion /
    // start-of-anonymous-onboarding so the next onboarding pass shows it again.
    // Persisted per-user for authenticated users (mirrors the hasCompletedPaywallFlow
    // pattern), and under a global key for anonymous users (they have no userId
    // at the moment they dismiss the prompt).
    @Published var hasSeenRatingPrompt: Bool = false {
        didSet {
            log("⭐ hasSeenRatingPrompt changed: \(oldValue) → \(hasSeenRatingPrompt)")
        }
    }

    // MARK: - Subscription Status
    @Published var hasActiveSubscription: Bool = false {
        didSet {
            log("💚 hasActiveSubscription changed: \(oldValue) → \(hasActiveSubscription)")
        }
    }

    @Published var subscriptionExpiryDate: Date? {
        didSet {
            log("📅 subscriptionExpiryDate changed: \(oldValue?.formatted() ?? "nil") → \(subscriptionExpiryDate?.formatted() ?? "nil")")
        }
    }

    @Published var currentUser: User? {
        didSet {
            log("👤 currentUser changed: \(oldValue?.email ?? "nil") → \(currentUser?.email ?? "nil")")
        }
    }
    
    @Published var isGoogleSignInLoading: Bool = false
    @Published var googleSignInError: String?
    
    @Published var isAppleSignInLoading: Bool = false
    @Published var appleSignInError: String?
    
    // MARK: - Anonymous User State
    @Published var isAnonymousUser: Bool = false {
        didSet {
            log("👻 isAnonymousUser changed: \(oldValue) → \(isAnonymousUser)")
        }
    }
    
    // Store the nonce for Apple Sign-In verification
    private var currentNonce: String?

    private let client = SupabaseManager.shared.client
    private var cancellables = Set<AnyCancellable>()
    
    // Google OAuth Client ID
    private let googleClientID = "915810938432-fh9l3u8icl6vcksn2j841c5nbljfh824.apps.googleusercontent.com"

    init() {
        log("\n🏁 ========== AuthManager INIT ==========")

        // Check if user has completed onboarding (seen landing pages)
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        log("📋 Loaded hasCompletedOnboarding: \(hasCompletedOnboarding)")

        // This global key might not be used in your current per-user storage,
        // but keeping it doesn't hurt; the real value loads after session.
        hasCompletedQuestions = UserDefaults.standard.bool(forKey: "hasCompletedQuestions")
        log("❓ Loaded hasCompletedQuestions: \(hasCompletedQuestions)")

        // Same note: actual per-user value loads after session
        hasCompletedPaywallFlow = UserDefaults.standard.bool(forKey: "hasCompletedPaywallFlow")
        log("💳 Loaded hasCompletedPaywallFlow: \(hasCompletedPaywallFlow)")

        // Load global rating-prompt flag — covers the anonymous case at launch,
        // and also provides a safe default before session restore overwrites
        // with the per-user value.
        hasSeenRatingPrompt = UserDefaults.standard.bool(forKey: "hasSeenRatingPrompt")
        log("⭐ Loaded hasSeenRatingPrompt: \(hasSeenRatingPrompt)")

        // Check if user is in anonymous mode
        isAnonymousUser = UserDefaults.standard.bool(forKey: "isAnonymousUser")
        log("👻 Loaded isAnonymousUser: \(isAnonymousUser)")

        // Don't setup subscription monitoring here - will be done after RevenueCat is configured

        // Listen to auth state changes
        Task {
            log("🎧 Starting to observe auth state changes...")
            await observeAuthState()
        }
    }

    // MARK: - Subscription Monitoring Setup
    /// Setup subscription monitoring - call this AFTER RevenueCat is configured
    func setupSubscriptionMonitoring() {
        log("🔐 AuthManager: Setting up subscription monitoring (RevenueCat ready)")

        // Listen for subscription status changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(subscriptionStatusChanged),
            name: SubscriptionManager.subscriptionStatusChangedNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(subscriptionExpired),
            name: SubscriptionManager.subscriptionExpiredNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(subscriptionRestored),
            name: SubscriptionManager.subscriptionRestoredNotification,
            object: nil
        )
        
        // Initial sync of subscription status
        syncSubscriptionStatus()
    }
    
    @objc private func subscriptionStatusChanged() {
        log("📢 AuthManager: Subscription status changed notification received")
        syncSubscriptionStatus()
    }
    
    @objc private func subscriptionExpired() {
        log("⚠️ AuthManager: Subscription expired notification received")
        syncSubscriptionStatus()
    }
    
    @objc private func subscriptionRestored() {
        log("✅ AuthManager: Subscription restored notification received")
        syncSubscriptionStatus()
    }
    
    private func syncSubscriptionStatus() {
        let subscriptionManager = SubscriptionManager.shared
        self.hasActiveSubscription = subscriptionManager.isSubscriptionActive
        self.subscriptionExpiryDate = subscriptionManager.subscriptionExpiryDate
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // AUTH STATE OBSERVER - THIS HANDLES AUTOMATIC NAVIGATION
    private func observeAuthState() async {
        log("\n🔄 observeAuthState() started")

        for await (event, session) in client.auth.authStateChanges {
            log("\n⚡️ ========== AUTH EVENT RECEIVED ==========")
            log("📡 Event: \(event)")
            log("🔑 Session exists: \(session != nil)")

            if let session = session {
                log("   - User ID: \(session.user.id)")
                log("   - Email: \(session.user.email ?? "nil")")
                log("   - Created at: \(session.user.createdAt)")
            }

            switch event {
            case .signedIn:
                log("✅ Event type: SIGNED_IN")
                if let session = session {
                    self.isAuthenticated = true
                    self.currentUser = session.user
                    UserDefaults.standard.set(session.user.id.uuidString, forKey: "current_user_id")

                    // ✅ Persist email immediately
                    if let email = session.user.email, !email.isEmpty {
                        UserDefaults.standard.set(email, forKey: "user_email")
                        log("📩 Saved user_email on sign-in: \(email)")
                    }

                    // ✅ Check if user was anonymous and sync data
                    // NOTE: syncAnonymousDataToBackend() handles setting hasCompletedPaywallFlow
                    // if the user had an active purchase during anonymous mode
                    if self.isAnonymousUser {
                        log("🔄 Detected anonymous user sign-in - syncing data...")
                        await self.syncAnonymousDataToBackend()
                    }

                    // ✅ Load user state (after sync, so we get the updated paywall flow status)
                    await checkUserQuestionStatus(userId: session.user.id.uuidString)
                    await checkUserPaywallFlowStatus(userId: session.user.id.uuidString)
                    await checkUserRatingPromptStatus(userId: session.user.id.uuidString)

                    // ✅ Hydrate lesson progress from Supabase user_metadata so
                    // users who reinstall / switch devices don't lose progress.
                    // Non-blocking; merges cloud + local and pushes back up.
                    await LessonDataService.shared.hydrateLessonProgressFromCloud()

                    log("✅ User signed in: \(session.user.email ?? "unknown")")
                    log("🎯 Auth state updated - RootView should now react")
                }

            case .signedOut:
                log("🚪 Event type: SIGNED_OUT")
                self.isAuthenticated = false
                self.currentUser = nil
                self.hasCompletedQuestions = false
                self.hasCompletedPaywallFlow = false
                self.hasSeenRatingPrompt = false
                log("🚪 User signed out")

            case .initialSession:
                log("🔵 Event type: INITIAL_SESSION")
                if let session = session {
                    self.isAuthenticated = true
                    self.currentUser = session.user

                    // ✅ Persist email on initial session
                    if let email = session.user.email, !email.isEmpty {
                        UserDefaults.standard.set(email, forKey: "user_email")
                        log("📩 Saved user_email on initial session: \(email)")
                    }

                    // ✅ Load user state
                    await checkUserQuestionStatus(userId: session.user.id.uuidString)
                    await checkUserPaywallFlowStatus(userId: session.user.id.uuidString)
                    await checkUserRatingPromptStatus(userId: session.user.id.uuidString)

                    // ✅ Hydrate lesson progress from Supabase user_metadata
                    // after session restoration so returning users (including
                    // post-reinstall) get their course progress back.
                    await LessonDataService.shared.hydrateLessonProgressFromCloud()

                    // ✅ NEW: If user was anonymous and already paid, skip paywall
                    let anonymousManager = AnonymousUserManager.shared
                    if self.isAnonymousUser && anonymousManager.hasActivePurchase {
                        log("💳 User was anonymous with active purchase - marking paywall flow as complete")
                        self.hasCompletedPaywallFlow = true
                        let key = "hasCompletedPaywallFlow_\(session.user.id.uuidString)"
                        UserDefaults.standard.set(true, forKey: key)
                    }

                    log("✅ Initial session found: \(session.user.email ?? "unknown")")
                } else {
                    self.isAuthenticated = false
                    log("❌ No initial session")
                }

            case .tokenRefreshed:
                log("🔄 Event type: TOKEN_REFRESHED")
                if let session = session {
                    self.currentUser = session.user
                    log("🔄 Token refreshed")
                }

            case .userUpdated:
                log("👤 Event type: USER_UPDATED")
                if let session = session {
                    self.currentUser = session.user
                    // Email generally doesn’t change, but this keeps it fresh
                    if let email = session.user.email, !email.isEmpty {
                        UserDefaults.standard.set(email, forKey: "user_email")
                        log("📩 Saved user_email on user update: \(email)")
                    }
                    log("👤 User updated")
                }

            case .passwordRecovery:
                log("🔑 Event type: PASSWORD_RECOVERY")
                log("🔑 Password recovery initiated")

            case .userDeleted:
                log("🗑️ Event type: USER_DELETED")
                self.isAuthenticated = false
                self.currentUser = nil
                self.hasCompletedQuestions = false
                self.hasCompletedPaywallFlow = false
                self.hasSeenRatingPrompt = false
                log("🗑️ User deleted")

            case .mfaChallengeVerified:
                // Emitted by Supabase when an MFA challenge is successfully
                // verified. The app does not use MFA flows today; no state
                // change is needed — the subsequent signedIn event (if any)
                // will drive routing. Logged for future observability.
                log("🔐 Event type: MFA_CHALLENGE_VERIFIED (no-op for current flows)")

            @unknown default:
                log("⚠️ Event type: UNKNOWN")
                log("⚠️ Unknown auth event")
            }

            log("========================================\n")
        }
    }

    // MARK: - Per-user status loads
    private func checkUserQuestionStatus(userId: String) async {
        let key = "hasCompletedQuestions_\(userId)"
        hasCompletedQuestions = UserDefaults.standard.bool(forKey: key)
        log("📋 User question status from UserDefaults: \(hasCompletedQuestions) for user: \(userId)")
        
        // Also check user metadata for onboarding completion (for synced anonymous users)
        if let user = currentUser,
           let onboardingCompleted = user.userMetadata["onboarding_completed"]?.boolValue,
           onboardingCompleted {
            log("📋 Found onboarding_completed=true in user metadata - marking as completed")
            hasCompletedQuestions = true
            hasCompletedOnboarding = true
            
            // Update UserDefaults to persist this state
            UserDefaults.standard.set(true, forKey: key)
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding_\(userId)")
        }
        
        log("📋 Final question status: \(hasCompletedQuestions) for user: \(userId)")
    }

    private func checkUserPaywallFlowStatus(userId: String) async {
        let key = "hasCompletedPaywallFlow_\(userId)"
        hasCompletedPaywallFlow = UserDefaults.standard.bool(forKey: key)
        log("💳 Paywall flow status loaded: \(hasCompletedPaywallFlow) for user: \(userId)")

        // Fallback: if UserDefaults says false (e.g. fresh install where the
        // Keychain-cached Supabase session restored a prior user), check
        // user_metadata. Mirrors the onboarding_completed pattern in
        // checkUserQuestionStatus above. Cache to UserDefaults on hit so
        // subsequent launches short-circuit on the local read.
        if !hasCompletedPaywallFlow,
           let user = currentUser,
           let paywallFlowCompleted = user.userMetadata["paywall_flow_completed"]?.boolValue,
           paywallFlowCompleted {
            log("💳 Found paywall_flow_completed=true in user metadata - marking as completed")
            hasCompletedPaywallFlow = true
            UserDefaults.standard.set(true, forKey: key)
        }
    }

    private func checkUserRatingPromptStatus(userId: String) async {
        let key = "hasSeenRatingPrompt_\(userId)"
        hasSeenRatingPrompt = UserDefaults.standard.bool(forKey: key)
        log("⭐ Rating prompt status loaded: \(hasSeenRatingPrompt) for user: \(userId)")
    }

    // MARK: - Graceful Session Restoration (Offline-First)
    
    /// Restores session from local cache instantly, then validates with server in background
    func restoreSessionGracefully() async {
        log("\n🔄 ========== GRACEFUL SESSION RESTORE ==========")
        
        do {
            // Step 1: Try to get cached session instantly (no network required)
            // Note: client.auth.session should read from local storage first
            let session = try await client.auth.session
            
            log("✅ Cached session found!")
            log("   - User ID: \(session.user.id)")
            log("   - Email: \(session.user.email ?? "nil")")
            
            // Immediately set authenticated state from cache
            self.currentUser = session.user
            self.isAuthenticated = true
            
            // Load user-specific states
            await checkUserQuestionStatus(userId: session.user.id.uuidString)
            await checkUserPaywallFlowStatus(userId: session.user.id.uuidString)
            await checkUserRatingPromptStatus(userId: session.user.id.uuidString)

            // Mark session check complete - UI can now render
            self.isCheckingSession = false
            log("✅ Session restored from cache - UI ready")
            
            // Step 2: Validate session with server in background (non-blocking)
            // Only if we have network connectivity
            if NetworkMonitor.shared.isConnected {
                Task.detached(priority: .background) { [weak self] in
                    await self?.validateSessionInBackground()
                }
            } else {
                log("📶 Offline - skipping background validation")
            }
            
        } catch {
            log("❌ No cached session found: \(error.localizedDescription)")
            
            // No session - user needs to log in
            self.isAuthenticated = false
            self.currentUser = nil
            self.isCheckingSession = false
            log("ℹ️ No session - showing login screen")
        }
        
        log("================================================\n")
    }
    
    /// Validates session with server in background, only signs out if truly invalid
    private func validateSessionInBackground() async {
        // Skip validation if offline - no point waiting for timeout
        guard NetworkMonitor.shared.isConnected else {
            log("📶 Background: Offline - skipping session validation")
            return
        }
        
        log("🔄 Background: Validating session with server...")
        
        // Use a timeout to prevent hanging
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    // Try to refresh the session token
                    let session = try await self.client.auth.refreshSession()
                    log("✅ Background: Session validated successfully")
                    log("   - Token refreshed for: \(session.user.email ?? "unknown")")
                }
                
                group.addTask {
                    // Timeout after 5 seconds
                    try await Task.sleep(nanoseconds: 5_000_000_000)
                    throw NSError(domain: "SessionValidation", code: -1, userInfo: [NSLocalizedDescriptionKey: "Timeout"])
                }
                
                // Wait for first task to complete (either success or timeout)
                try await group.next()
                group.cancelAll()
            }
        } catch {
            log("⚠️ Background: Session validation failed: \(error.localizedDescription)")
            
            // Only sign out if it's a real auth error, not a network error or timeout
            if isNetworkError(error) || error.localizedDescription.contains("Timeout") {
                log("📶 Background: Network error/timeout - keeping cached session")
                // Don't sign out, user might just be offline
            } else if isAuthenticationError(error) {
                log("🔐 Background: Auth error detected - session is invalid")
                // Token is truly invalid, sign out gracefully
                await signOut()
            } else {
                log("❓ Background: Unknown error - keeping cached session for safety")
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
        log("✅ completeOnboarding() called")
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }

    func skipOnboarding() {
        log("⏭️ skipOnboarding() called")
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
    
    // MARK: - Anonymous User Methods
    func startAnonymousOnboarding() {
        log("👻 startAnonymousOnboarding() called")
        isAnonymousUser = true
        hasCompletedOnboarding = false
        UserDefaults.standard.set(true, forKey: "isAnonymousUser")

        // Reset the rating prompt so this anonymous onboarding pass shows it
        // again. Without this, an earlier anonymous session that dismissed the
        // prompt leaves the global key set, causing the new flow to skip it.
        hasSeenRatingPrompt = false
        UserDefaults.standard.removeObject(forKey: "hasSeenRatingPrompt")

        // Also reset the paywall-flow flag for this fresh anonymous pass.
        // Otherwise, if an earlier anonymous user dismissed the paywall and
        // their in-memory flag somehow leaked (or a future code path persists
        // it globally), the new pass would skip the paywall. Defensive — the
        // current Phase-1 implementation only sets this flag in-memory for
        // anonymous users, but resetting here makes the per-pass invariant
        // explicit and robust to future changes.
        hasCompletedPaywallFlow = false

        log("✅ Anonymous onboarding started - user will proceed without account")
    }
    
    func completeAnonymousOnboarding() {
        log("👻 completeAnonymousOnboarding() called")
        hasCompletedOnboarding = true
        // Mirror into hasCompletedQuestions so the in-memory flag is already
        // true at the moment `.signedIn` fires. AuthManager is session-scoped,
        // so this value survives the anonymous → signup transition and keeps
        // RootView's line-97 check (`!hasCompletedQuestions`) from briefly
        // routing to OnboardingView while `syncAnonymousDataToBackend` is
        // still in flight. The per-user UserDefaults key is written by the
        // sync itself after signup — this flag is in-memory only.
        hasCompletedQuestions = true
        AnonymousUserManager.shared.hasCompletedOnboarding = true
        log("✅ Anonymous onboarding completed - data stored locally")
        AnonymousUserManager.shared.printCurrentData()
    }
    
    func syncAnonymousDataToBackend() async {
        log("🔄 syncAnonymousDataToBackend() called")
        
        let anonymousManager = AnonymousUserManager.shared
        
        guard let currentUser = currentUser else {
            log("❌ No authenticated user to sync data to")
            return
        }
        
        log("📤 Syncing anonymous data to backend for user: \(currentUser.id)")

        // Capture ALL anonymous state up-front, BEFORE any await. These locals
        // drive both the local UserDefaults writes (Phase 1 below) and the
        // cloud user_metadata write (Phase 2). Capturing first ensures no
        // interleaved Supabase auth event between awaits can change our
        // source of truth mid-sync, and ensures we read from the durable
        // anonymous-scope state rather than the fragile @Published in-memory
        // flags (which get overwritten by checkUser* calls run by the signedIn
        // handler after this function returns).
        let userId = currentUser.id.uuidString
        let hadActivePurchase = anonymousManager.hasActivePurchase
        let hadCompletedPaywallFlow = anonymousManager.hasCompletedPaywallFlow
        let reachedPaywallEndState = hadActivePurchase || hadCompletedPaywallFlow
        let hadCompletedOnboarding = anonymousManager.hasCompletedOnboarding
        let hadSeenRatingPrompt = UserDefaults.standard.bool(forKey: "hasSeenRatingPrompt")
        let userAge = anonymousManager.userAge
        let userGoals = anonymousManager.userGoals
        let typedName = anonymousManager.userName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // Only carry forward a display name we actually captured. Anonymous
        // onboarding no longer collects a name, so `typedName` will normally
        // be empty — in that case we intentionally leave display_name alone,
        // because SIWA/Google populate it on sign-in and writing "User" here
        // would clobber the provider-supplied name. The `typedName` path is
        // preserved for legacy data still in AnonymousUserManager from
        // previous app versions.
        let needsLinking = anonymousManager.needsRevenueCatLinking
        log("💳 Anonymous flags — purchase=\(hadActivePurchase) paywallComplete=\(hadCompletedPaywallFlow) onboarding=\(hadCompletedOnboarding) rating=\(hadSeenRatingPrompt)")

        // =====================================================================
        // PHASE 1: Local state writes (synchronous, no-await)
        // =====================================================================
        // These run BEFORE any network await so nothing can interleave and
        // no network failure can skip them. Local state is the source of
        // truth for routing (RootView reads @Published flags and UserDefaults),
        // so it MUST be consistent regardless of cloud outcome.

        if hadCompletedOnboarding {
            hasCompletedOnboarding = true
            hasCompletedQuestions = true
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding_\(userId)")
            UserDefaults.standard.set(true, forKey: "hasCompletedQuestions_\(userId)")
            log("✅ Marked onboarding and questions as completed for user: \(userId)")
        }

        if reachedPaywallEndState {
            hasCompletedPaywallFlow = true
            UserDefaults.standard.set(true, forKey: "hasCompletedPaywallFlow_\(userId)")
            log("💳 Anonymous paywall flow transferred — purchase=\(hadActivePurchase) completed=\(hadCompletedPaywallFlow)")
        }

        // Transfer the anonymous-scope rating-prompt flag to the per-user key.
        // Without this, dismissing users see RatingPromptView again after
        // signup because checkUserRatingPromptStatus reads only the per-user
        // key. Remove the global key after transfer to prevent bleed into a
        // future anonymous pass on the same device.
        if hadSeenRatingPrompt {
            hasSeenRatingPrompt = true
            UserDefaults.standard.set(true, forKey: "hasSeenRatingPrompt_\(userId)")
            UserDefaults.standard.removeObject(forKey: "hasSeenRatingPrompt")
            log("⭐ Transferred anonymous rating-prompt flag to per-user key for user: \(userId)")
        }

        // Reflect a typed display name in the local profile store immediately,
        // so the UI is consistent even if the cloud write fails. Skipped when
        // no name was captured during anonymous onboarding — the provider
        // (SIWA/Google) already populated UserProfileStore on sign-in.
        if !typedName.isEmpty {
            UserProfileStore.shared.apply(name: typedName)
        }

        // Clear anonymous state now that we've captured everything and
        // written durable per-user equivalents. This must happen BEFORE the
        // cloud await so a crash during the network call doesn't leave us
        // half-migrated (routing would still land on MainTabView because
        // per-user flags are already set, but isAnonymousUser flag would
        // linger otherwise).
        anonymousManager.clearAllData()
        isAnonymousUser = false
        UserDefaults.standard.removeObject(forKey: "isAnonymousUser")
        log("✅ Cleared anonymous user state")

        // =====================================================================
        // PHASE 2: Cloud metadata write (best-effort, failures don't regress)
        // =====================================================================
        // user_metadata is used for cross-device rehydration (signing in on a
        // new device reads these fields via checkUserQuestionStatus). Failure
        // here degrades that one narrow case but does not affect this device's
        // state — the user proceeds normally.
        do {
            var updates: [String: AnyJSON] = [:]
            if !typedName.isEmpty {
                updates["display_name"] = AnyJSON.string(typedName)
                log("   - Syncing name: \(typedName)")
            }

            if let age = userAge {
                updates["age"] = AnyJSON.string(age)
                log("   - Syncing age: \(age)")
            }

            if let goals = userGoals {
                updates["goals"] = AnyJSON.string(goals)
                log("   - Syncing goals: \(goals)")
            }

            if hadCompletedOnboarding {
                updates["onboarding_completed"] = AnyJSON.bool(true)
                log("   - Marking onboarding as completed")
            }

            if reachedPaywallEndState {
                updates["paywall_flow_completed"] = AnyJSON.bool(true)
                log("   - Marking paywall flow as completed")
            }

            updates["updated_at"] = AnyJSON.string(ISO8601DateFormatter().string(from: Date()))

            let attributes = UserAttributes(data: updates)
            try await client.auth.update(user: attributes)
            log("✅ Successfully synced anonymous data to backend")
        } catch {
            log("⚠️ Failed to sync anonymous data to backend: \(error.localizedDescription) — local state already written, user can continue")
        }

        // =====================================================================
        // PHASE 3: Independent best-effort follow-ups
        // =====================================================================
        // These are each wrapped in their own internal error handling (both
        // are non-throwing async functions) so they run even if Phase 2 failed.

        // Capture App Store storefront + currency now that we have a user
        // record to write to. We couldn't do this while anonymous.
        await captureStoreContextFromStoreKit()

        // Link RevenueCat purchases made while anonymous to the new userId.
        if needsLinking {
            log("🔗 Starting RevenueCat customer linking...")
            let linkSuccess = await RevenueCatManager.shared.linkAnonymousUserPurchases(userId)
            if linkSuccess {
                log("✅ RevenueCat purchases successfully linked")
            } else {
                log("⚠️ RevenueCat purchase linking may have failed")
            }
        }
    }

    // MARK: - Age Range Sync
    /// Writes the user's age range to `auth.users.user_metadata.age` for the
    /// currently authenticated user. Best-effort: failures are logged and
    /// swallowed (local UserDefaults retains the answer, so nothing is lost).
    ///
    /// Called from OnboardingView when a non-anonymous user answers the age
    /// question. Anonymous-signup users already get the same field synced
    /// via `syncAnonymousDataToBackend` — this method fills the gap for
    /// direct OAuth signups.
    func syncAgeRangeToBackend(_ ageRange: String) async {
        guard SupabaseManager.shared.currentUserId != nil else {
            log("⚠️ syncAgeRangeToBackend: no authenticated user — skipping")
            return
        }

        let trimmed = ageRange.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            log("⚠️ syncAgeRangeToBackend: empty age — skipping")
            return
        }

        log("📤 syncAgeRangeToBackend: writing age=\(trimmed) to user_metadata")

        do {
            let attributes = UserAttributes(data: [
                "age": AnyJSON.string(trimmed),
                "updated_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))
            ])
            try await client.auth.update(user: attributes)
            log("✅ syncAgeRangeToBackend: wrote age to user_metadata")
        } catch {
            log("❌ syncAgeRangeToBackend: failed — \(error.localizedDescription)")
        }
    }

    // MARK: - Store Context Capture

    /// Resolves App Store storefront country (StoreKit 2) and currency
    /// (from any loaded RevenueCat StoreProduct), then delegates the actual
    /// metadata write to `captureStoreContext(country:currency:)`. Used from
    /// `syncAnonymousDataToBackend` so anonymous-then-signup users get their
    /// country/currency captured at signup time, without needing to revisit
    /// the paywall.
    ///
    /// RevenueCat caches offerings after the user's anonymous paywall visit,
    /// so this call is typically served from cache — no extra network hit.
    private func captureStoreContextFromStoreKit() async {
        // Country from StoreKit 2 storefront.
        var country: String? = nil
        if let storefront = await Storefront.current {
            country = storefront.countryCode
        }

        // Currency from any loaded StoreProduct — yearly preferred, monthly fallback.
        var currency: String? = nil
        do {
            let offerings = try await Purchases.shared.offerings()
            let yearly = offerings.current?.package(identifier: "yearly") ?? offerings.current?.annual
            let monthly = offerings.current?.package(identifier: "monthly") ?? offerings.current?.monthly
            currency = yearly?.storeProduct.currencyCode ?? monthly?.storeProduct.currencyCode
        } catch {
            log("⚠️ captureStoreContextFromStoreKit: offerings fetch failed — \(error.localizedDescription)")
        }

        await captureStoreContext(country: country, currency: currency)
    }

    /// Writes App Store storefront country + currency to `user_metadata` for
    /// the currently authenticated user. Best-effort, idempotent per user per
    /// install via `hasCapturedStoreContext_<userId>` in UserDefaults — runs
    /// exactly once then no-ops on subsequent calls.
    ///
    /// Called from `PaywallViewModel.loadOfferings()` after offerings load,
    /// and from `syncAnonymousDataToBackend` after anonymous signup completes.
    /// Silently skips if no authenticated user exists.
    func captureStoreContext(country: String?, currency: String?) async {
        guard let userId = SupabaseManager.shared.currentUserId else {
            log("⚠️ captureStoreContext: no authenticated user — skipping")
            return
        }

        let flagKey = "hasCapturedStoreContext_\(userId)"
        if UserDefaults.standard.bool(forKey: flagKey) {
            // Already captured for this user on this install — no-op.
            return
        }

        // Need at least one useful field to bother writing.
        guard country != nil || currency != nil else {
            log("⚠️ captureStoreContext: no country/currency available — skipping")
            return
        }

        log("📤 captureStoreContext: country=\(country ?? "nil") currency=\(currency ?? "nil")")

        var updates: [String: AnyJSON] = [:]
        if let country = country {
            updates["country"] = AnyJSON.string(country)
        }
        if let currency = currency {
            updates["currency"] = AnyJSON.string(currency)
        }
        updates["store_context_captured_at"] = AnyJSON.string(ISO8601DateFormatter().string(from: Date()))

        do {
            let attributes = UserAttributes(data: updates)
            try await client.auth.update(user: attributes)
            UserDefaults.standard.set(true, forKey: flagKey)
            log("✅ captureStoreContext: wrote to user_metadata")
        } catch {
            // Best-effort — don't flip the flag, so next paywall open retries.
            log("❌ captureStoreContext: failed — \(error.localizedDescription)")
        }
    }

    // MARK: - Questions
    func completeQuestions() {
        log("✅ completeQuestions() called")
        hasCompletedQuestions = true

        // Save per user
        if let userId = currentUser?.id.uuidString {
            let key = "hasCompletedQuestions_\(userId)"
            UserDefaults.standard.set(true, forKey: key)
            log("✅ Questions completed for user: \(userId)")
        }
    }

    // MARK: - Paywall Flow (Paywall + Referral)
    /// Marks the paywall flow as complete. Called from two paths:
    ///   1. After a successful purchase (existing behavior).
    ///   2. After the user dismisses a dismissible paywall (Phase 1).
    /// In both cases the semantics are the same: "user reached an end state on
    /// the routing-level paywall." Whether they actually paid is answered by
    /// `hasActiveSubscription`, not by this flag.
    ///
    /// For an anonymous caller, also persists the state to
    /// `AnonymousUserManager` as a durable signal. Previously we only set the
    /// in-memory flag, which was fragile: any Supabase auth event that ran
    /// `checkUserPaywallFlowStatus` between dismissal and the sync would
    /// overwrite the flag with the (still-false) per-user value, silently
    /// losing the dismissal and bouncing the user back to the paywall after
    /// account creation. The durable AM flag is immune to that race and also
    /// survives app-quit. Cleared by `AnonymousUserManager.clearAllData()`
    /// at the end of sync, so no cross-user contamination on shared devices.
    func completePaywallFlow() {
        log("✅ completePaywallFlow() called")
        hasCompletedPaywallFlow = true

        if let userId = currentUser?.id.uuidString {
            let key = "hasCompletedPaywallFlow_\(userId)"
            UserDefaults.standard.set(true, forKey: key)
            log("✅ Paywall flow completed for user: \(userId)")

            // Mirror to user_metadata so this survives uninstall+reinstall.
            // The Supabase session persists in iOS Keychain across app deletes,
            // but per-user UserDefaults keys do not — without this write, a
            // reinstalling user gets re-routed through RatingPromptView and
            // PaywallView. Best-effort: UserDefaults remains the source of
            // truth on this device, so a network failure here only delays
            // cross-install rehydration to the next successful write.
            Task {
                do {
                    let attributes = UserAttributes(data: [
                        "paywall_flow_completed": AnyJSON.bool(true)
                    ])
                    try await client.auth.update(user: attributes)
                    log("✅ Mirrored paywall_flow_completed=true to user_metadata")
                } catch {
                    log("⚠️ Failed to mirror paywall_flow_completed to user_metadata: \(error.localizedDescription)")
                }
            }
        } else {
            AnonymousUserManager.shared.hasCompletedPaywallFlow = true
            log("✅ Paywall flow completed (anonymous) — persisted to AnonymousUserManager until signup")
        }
    }

    // MARK: - Rating Prompt
    /// Called from `RatingPromptView` when the user taps Continue.
    /// Flips the in-memory flag and persists — per-user key for authenticated
    /// users, global key for anonymous users (since they have no userId yet).
    func completeRatingPrompt() {
        log("⭐ completeRatingPrompt() called")
        hasSeenRatingPrompt = true

        if let userId = currentUser?.id.uuidString {
            let key = "hasSeenRatingPrompt_\(userId)"
            UserDefaults.standard.set(true, forKey: key)
            log("⭐ Rating prompt marked seen for user: \(userId)")
        } else {
            // Anonymous: persist under the global key so the next init() load
            // picks it up, and so the check during routing finds it.
            UserDefaults.standard.set(true, forKey: "hasSeenRatingPrompt")
            log("⭐ Rating prompt marked seen (anonymous)")
        }
    }

    // MARK: - Google Sign-In
    func signInWithGoogle() async {
        log("\n🔵 signInWithGoogle() called")
        
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
            
            log("✅ Google Sign-In successful")
            log("   - User: \(result.user.profile?.email ?? "unknown")")
            log("   - ID Token obtained: \(idToken.prefix(20))...")
            
            // Sign in to Supabase with the Google ID token
            let session = try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken,
                    accessToken: accessToken
                )
            )
            
            log("✅ Supabase sign-in successful")
            log("   - User ID: \(session.user.id)")
            log("   - Email: \(session.user.email ?? "nil")")
            
            // Mark onboarding as complete since user used social login
            completeOnboarding()
            
            isGoogleSignInLoading = false
            
        } catch let error as GIDSignInError {
            isGoogleSignInLoading = false
            
            // Handle user cancellation gracefully
            if error.code == .canceled {
                log("ℹ️ Google Sign-In cancelled by user")
                googleSignInError = nil
            } else {
                log("❌ Google Sign-In error: \(error.localizedDescription)")
                googleSignInError = error.localizedDescription
            }
            
        } catch let error as GoogleSignInError {
            isGoogleSignInLoading = false
            log("❌ Google Sign-In error: \(error.localizedDescription)")
            googleSignInError = error.localizedDescription
            
        } catch {
            isGoogleSignInLoading = false
            log("❌ Supabase sign-in error: \(error.localizedDescription)")
            googleSignInError = "Sign-in failed: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Apple Sign-In
    func signInWithApple() {
        log("\n🍎 signInWithApple() called")

        isAppleSignInLoading = true
        appleSignInError = nil

        // Generate a random nonce for security
        let nonce: String
        do {
            nonce = try randomNonceString()
        } catch {
            log("❌ Nonce generation failed: \(error.localizedDescription)")
            isAppleSignInLoading = false
            appleSignInError = "Couldn't start sign-in. Please try again."
            return
        }
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
        log("✅ Apple Sign-In successful, signing in with Supabase...")
        
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
            
            log("✅ Supabase Apple sign-in successful")
            log("   - User ID: \(session.user.id)")
            log("   - Email: \(session.user.email ?? "nil")")
            
            // If we got the full name (first sign-in only), save it to user metadata
            if let fullName = fullName {
                let displayName = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }
                    .joined(separator: " ")
                
                if !displayName.isEmpty {
                    log("📝 Saving display name: \(displayName)")
                    
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
            log("❌ Supabase Apple sign-in error: \(error.localizedDescription)")
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
                log("ℹ️ Apple Sign-In cancelled by user")
                appleSignInError = nil
                return
            case .failed:
                log("❌ Apple Sign-In failed")
                appleSignInError = "Sign-in failed. Please try again."
            case .invalidResponse:
                log("❌ Apple Sign-In invalid response")
                appleSignInError = "Invalid response from Apple. Please try again."
            case .notHandled:
                log("❌ Apple Sign-In not handled")
                appleSignInError = "Sign-in was not handled. Please try again."
            case .notInteractive:
                log("❌ Apple Sign-In not interactive")
                appleSignInError = "Sign-in requires user interaction."
            case .unknown:
                log("❌ Apple Sign-In unknown error")
                appleSignInError = "An unknown error occurred. Please try again."
            case .matchedExcludedCredential:
                // Passkey-registration path; not produced by the Sign-In-with-
                // Apple flow this app uses. Treat as a generic failure so the
                // user can retry.
                log("❌ Apple Sign-In: matchedExcludedCredential")
                appleSignInError = "Sign-in failed. Please try again."
            case .credentialImport, .credentialExport:
                // Passkey import/export errors; not reachable from SIWA here.
                log("❌ Apple Sign-In: credential import/export error")
                appleSignInError = "Sign-in failed. Please try again."
            case .preferSignInWithApple:
                // User opted to continue with an existing SIWA account. Since
                // this flow IS SIWA, treat as a generic cancel/retry prompt.
                log("ℹ️ Apple Sign-In: preferSignInWithApple")
                appleSignInError = nil
            case .deviceNotConfiguredForPasskeyCreation:
                // Passkey-specific; not reachable from SIWA. Log and surface a
                // retry-friendly message.
                log("❌ Apple Sign-In: deviceNotConfiguredForPasskeyCreation")
                appleSignInError = "Sign-in failed. Please try again."
            @unknown default:
                log("❌ Apple Sign-In unknown error code")
                appleSignInError = error.localizedDescription
            }
        } else {
            log("❌ Apple Sign-In error: \(error.localizedDescription)")
            appleSignInError = error.localizedDescription
        }
    }
    
    // MARK: - Nonce Generation Helpers
    private func randomNonceString(length: Int = 32) throws -> String {
        precondition(length > 0)
        var randomBytes = [UInt8](repeating: 0, count: length)
        let errorCode = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if errorCode != errSecSuccess {
            throw AppleSignInError.nonceGenerationFailed(errorCode)
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
        log("\n🚪 signOut() called")
        do {
            try await client.auth.signOut()

            // Capture userId BEFORE clearing currentUser so we can wipe the
            // per-user rating-prompt key (otherwise the next onboarding pass
            // for this user would re-load `true` from UserDefaults and skip
            // the rating screen).
            let userIdForCleanup = currentUser?.id.uuidString

            isAuthenticated = false
            currentUser = nil
            hasCompletedQuestions = false
            hasCompletedPaywallFlow = false
            hasSeenRatingPrompt = false

            if let userId = userIdForCleanup {
                UserDefaults.standard.removeObject(forKey: "hasSeenRatingPrompt_\(userId)")
            }

            log("✅ Sign out successful")
        } catch {
            log("❌ Sign out error: \(error.localizedDescription)")
        }
    }

    func resetOnboarding() {
        log("🔄 resetOnboarding() called")
        hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }

    func resetQuestions() {
        log("🔄 resetQuestions() called")
        hasCompletedQuestions = false
        if let userId = currentUser?.id.uuidString {
            let key = "hasCompletedQuestions_\(userId)"
            UserDefaults.standard.set(false, forKey: key)
            log("🔄 Questions reset for user: \(userId)")
        }
    }

    func resetPaywallFlow() {
        log("🔄 resetPaywallFlow() called")
        hasCompletedPaywallFlow = false
        if let userId = currentUser?.id.uuidString {
            let key = "hasCompletedPaywallFlow_\(userId)"
            UserDefaults.standard.set(false, forKey: key)
            log("🔄 Paywall flow reset for user: \(userId)")
        }
    }

    // MARK: - Account Deletion
    func deleteAccount() async throws {
        log("\n🗑️ deleteAccount() called")
        
        guard let currentUser = currentUser else {
            throw AccountDeletionError.notAuthenticated
        }
        
        guard let session = try? await client.auth.session else {
            throw AccountDeletionError.invalidSession
        }
        
        let userId = currentUser.id.uuidString
        log("🗑️ Starting account deletion for user: \(userId)")
        
        do {
            // Call the Supabase Edge Function using direct HTTP request
            // Since functions.invoke is not working, use URLSession directly
            guard let functionURL = URL(string: "https://bnckmgnysfliiypvxxii.supabase.co/functions/v1/delete-user-account") else {
                throw AccountDeletionError.networkError("Invalid delete-account function URL")
            }
            
            var request = URLRequest(url: functionURL)
            request.httpMethod = "POST"
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJuY2ttZ255c2ZsaWl5cHZ4eGlpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzM1NDc2NjIsImV4cCI6MjA0OTEyMzY2Mn0.IEcnoOKUbEUqXSZfZ4S6VbxZhb9z_YJXvVcgKLOeXXs", forHTTPHeaderField: "apikey")
            request.httpBody = Data() // Empty body as user ID comes from JWT
            
            log("🔄 Calling edge function at: \(functionURL.absoluteString)")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw AccountDeletionError.invalidResponse
            }
            
            log("✅ Edge function response received with status: \(httpResponse.statusCode)")
            
            // Log the raw response data for debugging 500 errors
            if let responseString = String(data: data, encoding: .utf8) {
                log("📄 Raw response body: \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                let decoder = JSONDecoder()
                let deletionResponse = try decoder.decode(AccountDeletionResponse.self, from: data)
                
                if deletionResponse.success {
                    log("✅ Account deletion successful: \(deletionResponse.message)")
                    log("🗑️ Deleted user ID: \(deletionResponse.deletedUserId ?? "unknown")")
                    
                    // Clear all local data
                    clearAllLocalData()
                    
                    // Update auth state
                    isAuthenticated = false
                    self.currentUser = nil
                    hasCompletedOnboarding = false
                    hasCompletedQuestions = false
                    hasCompletedPaywallFlow = false
                    hasSeenRatingPrompt = false
                    isCheckingSession = false

                    log("✅ Account deletion completed successfully")
                    
                } else {
                    log("❌ Account deletion failed: \(deletionResponse.error ?? "Unknown error")")
                    throw AccountDeletionError.deletionFailed(deletionResponse.error ?? "Unknown error")
                }
            } else {
                // Try to parse error response
                if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errorMessage = errorData["error"] as? String {
                    throw AccountDeletionError.deletionFailed(errorMessage)
                } else {
                    throw AccountDeletionError.deletionFailed("HTTP \(httpResponse.statusCode)")
                }
            }
            
        } catch let error as AccountDeletionError {
            throw error
        } catch {
            log("❌ Account deletion error: \(error.localizedDescription)")
            throw AccountDeletionError.networkError(error.localizedDescription)
        }
    }
    
    private func clearAllLocalData() {
        log("🧹 Clearing all local data...")
        
        // Clear user-specific data
        let userDefaults = UserDefaults.standard
        let userId = currentUser?.id.uuidString ?? ""
        
        // Remove user-specific keys
        userDefaults.removeObject(forKey: "hasCompletedOnboarding_\(userId)")
        userDefaults.removeObject(forKey: "hasCompletedQuestions_\(userId)")
        userDefaults.removeObject(forKey: "hasCompletedPaywallFlow_\(userId)")
        userDefaults.removeObject(forKey: "hasSeenRatingPrompt_\(userId)")
        // Leftover keys from the pre-gating hasEverHadSubscription flag. The
        // flag was removed when feature gates were added — these removes
        // clean up stale values on upgraded installs. Harmless no-op on
        // fresh installs.
        userDefaults.removeObject(forKey: "hasEverHadSubscription_\(userId)")
        userDefaults.removeObject(forKey: "hasEverHadSubscription_migrated_v1_\(userId)")
        userDefaults.removeObject(forKey: "current_user_id")
        userDefaults.removeObject(forKey: "user_email")
        userDefaults.removeObject(forKey: "user_name")
        
        // Clear general app data
        userDefaults.removeObject(forKey: "hasCompletedOnboarding")
        userDefaults.removeObject(forKey: "daily_reading_goal")
        userDefaults.removeObject(forKey: "goal_notifications")
        
        // Clear anonymous user data
        userDefaults.removeObject(forKey: "isAnonymousUser")
        AnonymousUserManager.shared.clearAllData()
        
        log("✅ All local data cleared")
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
    case nonceGenerationFailed(OSStatus)

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
        case .nonceGenerationFailed(let status):
            return "Couldn't generate sign-in security token (OSStatus \(status))"
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
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window
        }
        // Fallback: return an empty anchor rather than crashing. Apple Sign-In
        // will fail cleanly and surface an error the user can retry from.
        log("⚠️ presentationAnchor: no window found, returning empty anchor")
        return ASPresentationAnchor()
    }
    
    // MARK: - ASAuthorizationControllerDelegate
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            log("❌ Invalid credential type")
            Task { @MainActor in
                authManager?.handleAppleSignInFailure(error: AppleSignInError.noIdentityToken)
            }
            return
        }
        
        guard let identityTokenData = appleIDCredential.identityToken,
              let identityToken = String(data: identityTokenData, encoding: .utf8) else {
            log("❌ Unable to get identity token")
            Task { @MainActor in
                authManager?.handleAppleSignInFailure(error: AppleSignInError.noIdentityToken)
            }
            return
        }
        
        log("✅ Apple authorization successful")
        log("   - User ID: \(appleIDCredential.user)")
        log("   - Email: \(appleIDCredential.email ?? "not provided")")
        log("   - Full Name: \(appleIDCredential.fullName?.givenName ?? "not provided") \(appleIDCredential.fullName?.familyName ?? "")")
        
        // Pass the token and name to AuthManager
        Task { @MainActor in
            await authManager?.handleAppleSignInSuccess(
                idToken: identityToken,
                fullName: appleIDCredential.fullName
            )
        }
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        log("❌ Apple authorization failed: \(error.localizedDescription)")
        Task { @MainActor in
            authManager?.handleAppleSignInFailure(error: error)
        }
    }
}
