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
import PostHog
import FacebookCore

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

    // One-time 50%-off-year-1 recovery offer, shown immediately after a user
    // dismisses the feature-gated paywall (never after onboarding, never to
    // an already-subscribed user). Persisted per-user, mirroring
    // hasCompletedPaywallFlow's shape exactly, so "shown once, ever" holds
    // across reinstall / new device.
    @Published var hasSeenSecondChanceOffer: Bool = false {
        didSet {
            log("🎁 hasSeenSecondChanceOffer changed: \(oldValue) → \(hasSeenSecondChanceOffer)")
        }
    }

    // MARK: - Free Demo (mascot walkthrough)
    //
    // These two answer questions that are deliberately separate from
    // `hasCompletedPaywallFlow`, which only records "passed paywall #1" and
    // must never be read as an entitlement — every existing non-paying user
    // already has it set to true, persisted per-user AND mirrored to
    // user_metadata, and it never expires.
    //
    //   hasCompletedFreeDemo     — walkthrough finished (1 scenario + 1
    //                              lesson spent). Ends demo mode and arms the
    //                              post-demo ask.
    //   hasDismissedPostDemoWall — user declined that ask. Lets them into the
    //                              app with the feature gates doing their
    //                              normal job.
    //
    // Both are new keys, so they default false for the entire existing
    // install base — those users correctly land in demo mode on first launch
    // after the update rather than being silently handed the app.
    //
    // Persisted per-user and mirrored to user_metadata, mirroring
    // hasSeenSecondChanceOffer's shape exactly, so both survive
    // uninstall+reinstall and new devices.
    @Published var hasCompletedFreeDemo: Bool = false {
        didSet {
            log("🎓 hasCompletedFreeDemo changed: \(oldValue) → \(hasCompletedFreeDemo)")
        }
    }

    @Published var hasDismissedPostDemoWall: Bool = false {
        didSet {
            log("🚧 hasDismissedPostDemoWall changed: \(oldValue) → \(hasDismissedPostDemoWall)")
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
    //
    // Two different things used to share the name "anonymous". They are now
    // named apart, because conflating them is how `.signedIn` for a guest
    // session came to trigger the whole anonymous→permanent data transfer:
    //
    //   isLegacyAnonymousUser — onboarding with NO Supabase session at all.
    //                           Local-only: a UserDefaults flag plus
    //                           AnonymousUserManager. Predates guest sessions.
    //   isGuestSession        — a real `auth.users` row with
    //                           `is_anonymous = true`, holding a live session.
    //
    // The "legacy" prefix is deliberate: this flag and the whole
    // AnonymousUserManager mirror are retired in Phase E, once a session exists
    // from first launch and there is nothing left to transfer. Do not build new
    // behaviour on it.
    //
    // NOTE: the backing UserDefaults key is still the string "isAnonymousUser".
    // Renaming the key would strand every user currently mid-onboarding — they
    // would read `false` on next launch and be routed as if they had never
    // started. The Swift symbol and the storage key are intentionally different.
    @Published var isLegacyAnonymousUser: Bool = false {
        didSet {
            log("👻 isLegacyAnonymousUser changed: \(oldValue) → \(isLegacyAnonymousUser)")
        }
    }

    /// True when the live Supabase session belongs to an anonymous (guest) user.
    ///
    /// Distinct from `isAuthenticated`, which means "has a **permanent**
    /// account". Routing keys off `hasSession` (either of the two), not
    /// `isAuthenticated` — a guest has a real `user_id` and can use the app.
    /// The two stay separate because Phase F needs to know which users still
    /// owe an account.
    @Published private(set) var isGuestSession: Bool = false {
        didSet {
            log("🎭 isGuestSession changed: \(oldValue) → \(isGuestSession)")
        }
    }

    /// In-flight guard so concurrent callers can't mint two guest users.
    @Published private(set) var isBootstrappingGuestSession: Bool = false

    /// Armed when a guest bootstrap deferred (offline) or failed, so it can be
    /// retried on the next network-restored transition.
    private var guestBootstrapPending = false

    /// Guest user id awaiting a RevenueCat `logIn` because the SDK was not yet
    /// configured when the session arrived. See `adoptGuestIdentity(_:)`.
    private var pendingGuestRevenueCatIdentity: String?

    /// Whether the post-purchase account ask has already been shown.
    ///
    /// Per-user and persisted, so declining it is remembered rather than
    /// re-asked on every launch — nagging a paying customer is exactly what the
    /// skippable design is trying to avoid. Phase G's Profile prompt is the
    /// durable follow-up for anyone who declines.
    ///
    /// Keyed on the guest's own id, which linking preserves, so the flag stays
    /// meaningful if they later create an account by another route.
    @Published private(set) var hasSeenPostPurchaseAccountAsk: Bool = false

    #if DEBUG
    /// Launch argument `-forcePostPurchaseAsk YES` — shows the ask without a
    /// real purchase, so the screen can be reviewed without buying something.
    @Published var forcePostPurchaseAsk: Bool = false
    #endif

    /// Highest prompt threshold this guest has already dismissed. 0 = never.
    ///
    /// Published rather than read from UserDefaults at the call site so
    /// dismissing the Profile prompt re-renders the view that shows it.
    @Published private(set) var guestPromptDismissedThreshold: Int = 0

    /// Approach counts at which a guest is offered an account from Profile.
    ///
    /// Escalating rather than persistent, and it stops after the second. The
    /// prompt protects the approach log — the one thing in this app that cannot
    /// be regenerated — so it should appear once there is a log worth
    /// protecting, ask again when there is materially more at stake, and then
    /// leave the user alone. A permanently-visible banner is a nag, and a
    /// user who has declined twice has answered.
    static let guestAccountPromptThresholds = [5, 25]

    /// Whether Profile should offer this guest an account right now.
    func shouldShowGuestAccountPrompt(approachCount: Int) -> Bool {
        guard isGuestSession else { return false }
        guard let reached = Self.guestAccountPromptThresholds
            .last(where: { approachCount >= $0 }) else { return false }
        return reached > guestPromptDismissedThreshold
    }

    /// Records a dismissal at the highest threshold currently reached, so the
    /// prompt re-arms only at the *next* tier rather than on the next render.
    func markGuestAccountPromptDismissed(approachCount: Int) {
        guard let reached = Self.guestAccountPromptThresholds
            .last(where: { approachCount >= $0 }) else { return }

        guestPromptDismissedThreshold = reached
        if let userId = currentUser?.id.uuidString {
            UserDefaults.standard.set(reached, forKey: Self.guestPromptDismissedKey(userId))
        }
        log("⏭️ Guest account prompt dismissed at threshold \(reached)")

        PostHogSDK.shared.capture("account_ask_skipped", properties: [
            "trigger": "profilePrompt",
            "approach_count": approachCount
        ])
    }

    private static func guestPromptDismissedKey(_ userId: String) -> String {
        "guestAccountPromptDismissedAt_\(userId)"
    }

    /// Whether RootView should present the post-purchase account ask.
    ///
    /// Guest-ness is checked by the caller; this answers "has this user bought
    /// something and not yet been asked?".
    var shouldShowPostPurchaseAccountAsk: Bool {
        guard !hasSeenPostPurchaseAccountAsk else { return false }
        #if DEBUG
        if forcePostPurchaseAsk { return true }
        #endif
        return hasActiveSubscription
    }

    /// Whether a usable Supabase session exists, guest or permanent.
    ///
    /// **This is what routing should ask.** `isAuthenticated` answers a narrower
    /// question — "does this user have a permanent account?" — which is the
    /// right input for the Phase F account ask, and the wrong input for "may
    /// this user use the app?". A guest holds a real `auth.users` row, so every
    /// user-scoped table, RLS policy and `currentUserId` guard works for them.
    var hasSession: Bool { isAuthenticated || isGuestSession }
    
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

        // Same note as above: actual per-user value loads after session
        hasSeenSecondChanceOffer = UserDefaults.standard.bool(forKey: "hasSeenSecondChanceOffer")
        log("🎁 Loaded hasSeenSecondChanceOffer: \(hasSeenSecondChanceOffer)")

        // Same note as above: pre-session defaults only. The authoritative
        // per-user values load in checkUserFreeDemoStatus /
        // checkUserPostDemoWallStatus once a session exists.
        hasCompletedFreeDemo = UserDefaults.standard.bool(forKey: "hasCompletedFreeDemo")
        log("🎓 Loaded hasCompletedFreeDemo: \(hasCompletedFreeDemo)")

        hasDismissedPostDemoWall = UserDefaults.standard.bool(forKey: "hasDismissedPostDemoWall")
        log("🚧 Loaded hasDismissedPostDemoWall: \(hasDismissedPostDemoWall)")

        // Load global rating-prompt flag — covers the anonymous case at launch,
        // and also provides a safe default before session restore overwrites
        // with the per-user value.
        hasSeenRatingPrompt = UserDefaults.standard.bool(forKey: "hasSeenRatingPrompt")
        log("⭐ Loaded hasSeenRatingPrompt: \(hasSeenRatingPrompt)")

        // Check if user is in anonymous mode
        isLegacyAnonymousUser = UserDefaults.standard.bool(forKey: "isAnonymousUser")
        log("👻 Loaded isLegacyAnonymousUser: \(isLegacyAnonymousUser)")

        // Don't setup subscription monitoring here - will be done after RevenueCat is configured

        observeNetworkForGuestBootstrap()
        observeFeatureFlagsForGuestBootstrap()

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
        #if DEBUG
        // Debug builds can force the premium entitlement on, but only when
        // explicitly asked for.
        //
        // This used to be an unconditional `#if DEBUG` grant, which meant a
        // Debug build could never exercise ANY non-subscriber path — the
        // feature gates, demo mode, and the post-demo wall all sit below
        // RootView's `hasActiveSubscription` check, so they were unreachable
        // on the only configuration where the debug overrides for those flags
        // are even compiled in. Opt-in instead: Debug now behaves like
        // production unless you ask otherwise.
        //
        // Launch argument: -forcePremium YES
        if UserDefaults.standard.bool(forKey: "forcePremium") {
            self.hasActiveSubscription = true
            log("💎 DEBUG: hasActiveSubscription FORCED true via -forcePremium")
        } else {
            self.hasActiveSubscription = subscriptionManager.isSubscriptionActive
        }
        #else
        self.hasActiveSubscription = subscriptionManager.isSubscriptionActive
        #endif
        self.subscriptionExpiryDate = subscriptionManager.subscriptionExpiryDate

        // Self-heal the routing flag. A paying user is, by definition, past
        // the paywall — but `hasCompletedPaywallFlow` can be stale-false on a
        // reinstall (per-user UserDefaults wiped) or new device when the
        // best-effort `paywall_flow_completed` user_metadata mirror failed at
        // a prior `completePaywallFlow()` call. Without this, RootView would
        // route a paying user back to PaywallView. `completePaywallFlow()` is
        // idempotent, so calling it when the flag is already true is a no-op.
        if self.hasActiveSubscription && !self.hasCompletedPaywallFlow {
            log("🩹 AuthManager: Self-healing hasCompletedPaywallFlow — paying user with stale flag")
            completePaywallFlow()
        }
    }

    /// Routing-level "paywall flow done" check. `hasActiveSubscription` is
    /// included so that paying users whose `hasCompletedPaywallFlow` flag is
    /// transiently false (reinstall before the heal in `syncSubscriptionStatus`
    /// runs, or first render before the cache loads) are routed to MainTabView
    /// instead of looping back through RatingPromptView/PaywallView. Cannot
    /// over-permit: `hasActiveSubscription` is sourced from RC/StoreKit data
    /// only, never user-controllable.
    var effectivePaywallFlowCompleted: Bool {
        hasCompletedPaywallFlow || hasActiveSubscription
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

                // Guest sessions emit .signedIn too — verified in supabase-swift
                // `AuthClient.swift:452-453`, where signInAnonymously() routes
                // through the same _signIn() that emits the event.
                //
                // They must NOT fall through to the branch below. That branch
                // calls syncAnonymousDataToBackend() whenever `isLegacyAnonymousUser`
                // is set, which for a guest would run the whole
                // anonymous→permanent transfer (including
                // AnonymousUserManager.clearAllData()) against a user who has
                // not created an account. It also runs the per-user flag loads,
                // which would overwrite the in-memory anonymous paywall flag —
                // precisely the race documented at
                // AnonymousUserManager.swift:59-71.
                if let session = session, session.user.isAnonymous {
                    self.markSessionEstablished(session.user)
                    self.isGuestSession = true
                    self.currentUser = session.user
                    self.adoptGuestIdentity(session.user.id.uuidString)
                    await self.loadGuestUserState(userId: session.user.id.uuidString)
                    log("🎭 Guest session signed in: \(session.user.id)")

                } else if let session = session {
                    self.markSessionEstablished(session.user)
                    self.isAuthenticated = true
                    // Signing into a real account replaces any guest session
                    // without emitting .signedOut, so this has to be cleared
                    // here or it stays true for the rest of the process.
                    self.isGuestSession = false
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
                    if self.isLegacyAnonymousUser {
                        log("🔄 Detected anonymous user sign-in - syncing data...")
                        await self.syncAnonymousDataToBackend()
                    }

                    // ✅ Load user state (after sync, so we get the updated paywall flow status)
                    await checkUserQuestionStatus(userId: session.user.id.uuidString)
                    await checkUserPaywallFlowStatus(userId: session.user.id.uuidString)
                    await checkUserRatingPromptStatus(userId: session.user.id.uuidString)
                    await checkUserSecondChanceOfferStatus(userId: session.user.id.uuidString)
                    await checkUserFreeDemoStatus(userId: session.user.id.uuidString)
                    await checkUserPostDemoWallStatus(userId: session.user.id.uuidString)

                    // ✅ Hydrate lesson progress from Supabase user_metadata so
                    // users who reinstall / switch devices don't lose progress.
                    // Non-blocking; merges cloud + local and pushes back up.
                    await LessonDataService.shared.hydrateLessonProgressFromCloud()

                    log("✅ User signed in: \(session.user.email ?? "unknown")")
                    log("🎯 Auth state updated - RootView should now react")

                    // PostHog: identify by Supabase UUID (no PII). If a prior
                    // anonymous identify was set at launch, PostHog merges
                    // events automatically via $anon_distinct_id.
                    let userId = session.user.id.uuidString
                    PostHogSDK.shared.identify(userId)

                    // Flag evaluation is per-distinct-id, so values resolved
                    // for the pre-signin anonymous id don't necessarily hold
                    // for this person. Re-pull now that identify() has run.
                    FeatureFlags.shared.refresh()

                    // Distinguish signup from login by createdAt freshness
                    // (60-second window). The provider field comes from
                    // Supabase appMetadata; falls back to "unknown".
                    let isNewUser = Date().timeIntervalSince(session.user.createdAt) < 60
                    let authMethod = session.user.appMetadata["provider"]?.stringValue ?? "unknown"
                    if isNewUser {
                        PostHogSDK.shared.capture("user_signed_up", properties: [
                            "method": authMethod
                        ])
                        // Meta: attributes installs/registrations back to the
                        // ad that drove them. Only fired for genuinely new
                        // accounts (same isNewUser gate as PostHog above) so
                        // repeat logins don't inflate the conversion count.
                        AppEvents.shared.logEvent(.completedRegistration, parameters: [
                            .registrationMethod: authMethod
                        ])
                    } else {
                        PostHogSDK.shared.capture("user_logged_in", properties: [
                            "method": authMethod
                        ])
                    }
                }

            case .signedOut:
                log("🚪 Event type: SIGNED_OUT")
                // RevenueCat logout lives HERE — on the deliberate sign-out
                // event — not on RootView's isAuthenticated onChange, which
                // also fires false on transient session-restore failures.
                // Supabase emits .signedOut only for an actual signOut()
                // (AuthManager.signOut and SettingsSheet.logOut both route
                // through it), never for network flakes.
                RevenueCatManager.shared.logoutUser()
                // PostHog: capture before reset so the event is still
                // attached to the outgoing distinct_id. reset() afterwards
                // clears the distinct_id and re-generates an anonymous one.
                PostHogSDK.shared.capture("user_logged_out")
                PostHogSDK.shared.reset()
                self.isAuthenticated = false
                self.currentUser = nil
                self.hasCompletedQuestions = false
                self.hasCompletedPaywallFlow = false
                self.hasSeenRatingPrompt = false
                self.hasSeenSecondChanceOffer = false
                self.hasCompletedFreeDemo = false
                self.hasDismissedPostDemoWall = false
                // Deliberate exit — Supabase emits .signedOut only for a real
                // signOut(), never for network flakes (see above). Clearing the
                // marker here is what lets someone who signs out and then taps
                // "Skip for now" get a fresh guest session.
                self.clearSessionEverMarker(reason: "signed out")
                log("🚪 User signed out")

            case .initialSession:
                log("🔵 Event type: INITIAL_SESSION")

                // Same split as .signedIn — a cached guest session restoring at
                // launch must not run the permanent-account state loads.
                if let session = session, session.user.isAnonymous {
                    self.markSessionEstablished(session.user)
                    self.isGuestSession = true
                    self.currentUser = session.user
                    self.adoptGuestIdentity(session.user.id.uuidString)
                    await self.loadGuestUserState(userId: session.user.id.uuidString)
                    log("🎭 Guest session restored: \(session.user.id)")

                } else if let session = session {
                    self.markSessionEstablished(session.user)
                    self.isAuthenticated = true
                    self.isGuestSession = false
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
                    await checkUserSecondChanceOfferStatus(userId: session.user.id.uuidString)
                    await checkUserFreeDemoStatus(userId: session.user.id.uuidString)
                    await checkUserPostDemoWallStatus(userId: session.user.id.uuidString)

                    // ✅ Hydrate lesson progress from Supabase user_metadata
                    // after session restoration so returning users (including
                    // post-reinstall) get their course progress back.
                    await LessonDataService.shared.hydrateLessonProgressFromCloud()

                    // ✅ NEW: If user was anonymous and already paid, skip paywall
                    let anonymousManager = AnonymousUserManager.shared
                    if self.isLegacyAnonymousUser && anonymousManager.hasActivePurchase {
                        log("💳 User was anonymous with active purchase - marking paywall flow as complete")
                        self.hasCompletedPaywallFlow = true
                        let key = "hasCompletedPaywallFlow_\(session.user.id.uuidString)"
                        UserDefaults.standard.set(true, forKey: key)
                    }

                    log("✅ Initial session found: \(session.user.email ?? "unknown")")

                    // PostHog: re-identify on session restore so events from
                    // returning users tie to their Supabase UUID. No PII.
                    PostHogSDK.shared.identify(session.user.id.uuidString)
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

                    // GUEST → PERMANENT promotion.
                    //
                    // `linkIdentityWithIdToken` emits .userUpdated rather than
                    // .signedIn (supabase-swift AuthClient.swift:1230-1231), so
                    // without this a linked user would keep `isGuestSession ==
                    // true` and `isAuthenticated == false` — the app would still
                    // treat them as a guest despite having a real account.
                    //
                    // The user id is unchanged by linking, so RevenueCat and
                    // PostHog are already identified correctly and need no
                    // second call. Only the per-user state loads are owed, since
                    // the guest branches in .signedIn / .initialSession skip
                    // them.
                    if !session.user.isAnonymous {
                        await self.promoteGuestToPermanent(session: session)
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
                self.hasSeenSecondChanceOffer = false
                self.hasCompletedFreeDemo = false
                self.hasDismissedPostDemoWall = false
                self.clearSessionEverMarker(reason: "user deleted")
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

    /// Same shape as `checkUserPaywallFlowStatus` above: per-user UserDefaults
    /// read first (fast, offline-safe), falling back to the `user_metadata`
    /// mirror on a miss (covers reinstall / new device), backfilling
    /// UserDefaults on a hit so later launches short-circuit locally.
    private func checkUserSecondChanceOfferStatus(userId: String) async {
        let key = "hasSeenSecondChanceOffer_\(userId)"
        hasSeenSecondChanceOffer = UserDefaults.standard.bool(forKey: key)
        log("🎁 Second-chance offer status loaded: \(hasSeenSecondChanceOffer) for user: \(userId)")

        if !hasSeenSecondChanceOffer,
           let user = currentUser,
           let shown = user.userMetadata["second_chance_offer_shown"]?.boolValue,
           shown {
            log("🎁 Found second_chance_offer_shown=true in user metadata - marking as shown")
            hasSeenSecondChanceOffer = true
            UserDefaults.standard.set(true, forKey: key)
        }
    }

    /// Same shape as `checkUserSecondChanceOfferStatus`: per-user UserDefaults
    /// first, `user_metadata` mirror as the reinstall / new-device fallback,
    /// backfilling UserDefaults on a hit.
    ///
    /// A miss on both means "demo not yet spent" — which is the correct
    /// reading for both a genuinely new user and the entire pre-update install
    /// base, since this key has never existed before.
    private func checkUserFreeDemoStatus(userId: String) async {
        let key = "hasCompletedFreeDemo_\(userId)"
        hasCompletedFreeDemo = UserDefaults.standard.bool(forKey: key)
        log("🎓 Free demo status loaded: \(hasCompletedFreeDemo) for user: \(userId)")

        if !hasCompletedFreeDemo,
           let user = currentUser,
           let completed = user.userMetadata["free_demo_completed"]?.boolValue,
           completed {
            log("🎓 Found free_demo_completed=true in user metadata - marking as completed")
            hasCompletedFreeDemo = true
            UserDefaults.standard.set(true, forKey: key)
        }

        #if DEBUG
        // Local override so the post-demo routing can be exercised before the
        // walkthrough (phase 6) exists to flip this for real.
        // Launch argument: -forceFreeDemoCompleted YES
        if UserDefaults.standard.object(forKey: "forceFreeDemoCompleted") != nil {
            hasCompletedFreeDemo = UserDefaults.standard.bool(forKey: "forceFreeDemoCompleted")
            log("🎓 hasCompletedFreeDemo OVERRIDDEN locally = \(hasCompletedFreeDemo)")
        }
        #endif
    }

    /// Companion to `checkUserFreeDemoStatus`. Only meaningful once the demo
    /// is spent; loaded unconditionally so RootView never has to wait on a
    /// second async hop after `hasCompletedFreeDemo` resolves.
    private func checkUserPostDemoWallStatus(userId: String) async {
        let key = "hasDismissedPostDemoWall_\(userId)"
        hasDismissedPostDemoWall = UserDefaults.standard.bool(forKey: key)
        log("🚧 Post-demo wall status loaded: \(hasDismissedPostDemoWall) for user: \(userId)")

        if !hasDismissedPostDemoWall,
           let user = currentUser,
           let dismissed = user.userMetadata["post_demo_wall_dismissed"]?.boolValue,
           dismissed {
            log("🚧 Found post_demo_wall_dismissed=true in user metadata - marking as dismissed")
            hasDismissedPostDemoWall = true
            UserDefaults.standard.set(true, forKey: key)
        }

        #if DEBUG
        // Companion to the override in checkUserFreeDemoStatus — lets a repeat
        // run re-arm the ask without wiping the app.
        // Launch argument: -forceDismissedPostDemoWall NO
        if UserDefaults.standard.object(forKey: "forceDismissedPostDemoWall") != nil {
            hasDismissedPostDemoWall = UserDefaults.standard.bool(forKey: "forceDismissedPostDemoWall")
            log("🚧 hasDismissedPostDemoWall OVERRIDDEN locally = \(hasDismissedPostDemoWall)")
        }
        #endif
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

            self.markSessionEstablished(session.user)

            // A cached guest session takes the same reduced path as the
            // .signedIn / .initialSession guest branches: mark, flag, render.
            // None of the per-user loads below apply to a user with no
            // permanent account, and Phase B deliberately leaves routing alone.
            if session.user.isAnonymous {
                self.currentUser = session.user
                self.isGuestSession = true
                self.adoptGuestIdentity(session.user.id.uuidString)
                await self.loadGuestUserState(userId: session.user.id.uuidString)
                self.isCheckingSession = false
                log("🎭 Guest session restored from cache: \(session.user.id) — UI ready")
                log("================================================\n")
                return
            }

            // Immediately set authenticated state from cache
            self.currentUser = session.user
            self.isAuthenticated = true
            self.isGuestSession = false

            // Load user-specific states
            await checkUserQuestionStatus(userId: session.user.id.uuidString)
            await checkUserPaywallFlowStatus(userId: session.user.id.uuidString)
            await checkUserRatingPromptStatus(userId: session.user.id.uuidString)
            await checkUserSecondChanceOfferStatus(userId: session.user.id.uuidString)
            await checkUserFreeDemoStatus(userId: session.user.id.uuidString)
            await checkUserPostDemoWallStatus(userId: session.user.id.uuidString)

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

            // Only mark unauthenticated if observeAuthState() hasn't already
            // established a session. This runs concurrently with the
            // .initialSession/.signedIn handlers, and unconditionally writing
            // false here could clobber a session they just set — RootView
            // would flip to logged-out (and previously also logged RevenueCat
            // out, orphaning an active subscription mid-flight).
            if self.currentUser == nil {
                self.isAuthenticated = false
                log("ℹ️ No session - showing login screen")
            } else {
                log("ℹ️ Session read failed but auth state already established — keeping it")
            }
            self.isCheckingSession = false
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
    
    // MARK: - Guest Session (Supabase anonymous auth)

    private static let hasEverHadSessionKey = "has_ever_had_session"

    /// Records that a Supabase session has existed on this device.
    ///
    /// **This marker is the entire safety mechanism for guest sessions**, and
    /// the reason bootstrap keys off a persisted flag rather than a live
    /// session read.
    ///
    /// `restoreSessionGracefully()` sets `isAuthenticated = false` whenever the
    /// session read throws — which covers transient failures, not just genuine
    /// sign-out. `SupabaseManager` configures the client with
    /// `autoRefreshToken: false`, so an expired token while offline surfaces
    /// exactly that way. If bootstrap simply asked "is there a session right
    /// now?", one such failure would mint a brand new anonymous user for an
    /// existing paying customer: a new `user_id` (their approach logs and
    /// progress invisible) plus an identified→identified RevenueCat switch that
    /// strands the entitlement on the old id. They would open the app to an
    /// empty account and a dead subscription.
    ///
    /// Cleared only on `.signedOut` and `.userDeleted`. Supabase emits those
    /// solely for a deliberate `signOut()`, never for network flakes (see the
    /// comment on the `.signedOut` case), so a user who signs out and then taps
    /// "Skip for now" correctly gets a fresh guest session, while a transient
    /// read failure never does.
    private var hasEverHadSession: Bool {
        get { UserDefaults.standard.bool(forKey: Self.hasEverHadSessionKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.hasEverHadSessionKey) }
    }

    #if DEBUG
    /// DEBUG-only launch-argument hooks, mirroring the `-forceFreeDemoCompleted`
    /// pattern established for phases 1-3. Without these, exercising guest
    /// bootstrap means driving the whole funnel by hand on every run.
    ///
    ///   -forceGuestBootstrap YES      run bootstrap at launch
    ///   -forceHasEverHadSession YES   pre-set the marker, so bootstrap must
    ///                                 REFUSE — this is the regression test for
    ///                                 the existing-paying-user guard
    func applyDebugGuestOverrides() async {
        if UserDefaults.standard.object(forKey: "forceHasEverHadSession") != nil {
            let forced = UserDefaults.standard.bool(forKey: "forceHasEverHadSession")
            hasEverHadSession = forced
            log("🧪 DEBUG: has_ever_had_session forced to \(forced)")
        }

        if UserDefaults.standard.bool(forKey: "forceGuestBootstrap") {
            log("🧪 DEBUG: forcing guest bootstrap at launch")
            await bootstrapGuestSessionIfNeeded()
        }

        if UserDefaults.standard.bool(forKey: "forcePostPurchaseAsk") {
            forcePostPurchaseAsk = true
            log("🧪 DEBUG: forcing post-purchase account ask")
        }
    }
    #endif

    private func markSessionEstablished(_ user: User) {
        if !hasEverHadSession {
            hasEverHadSession = true
            log("🔐 has_ever_had_session set (user: \(user.id), anonymous: \(user.isAnonymous))")
        }
    }

    /// Points RevenueCat and PostHog at the guest's Supabase user id.
    ///
    /// This is the whole of Phase D's behaviour change, and it is safe only
    /// because `authenticate(with:)` links rather than re-signs-in: the id
    /// established here is the *same* id the account ends up with, so this is
    /// the one and only `Purchases.logIn` in a user's lifetime.
    ///
    /// `Purchases.configure()` still runs **without** an appUserID — the warning
    /// at `RevenueCatManager.swift:68-75` is about `configure`, not `logIn`, and
    /// still applies. RevenueCat is anonymous (`$RCAnonymousID`) until this
    /// call, so this remains the anonymous→identified transition that transfers
    /// correctly. There is no later identified→identified switch to strand a
    /// purchase, which is what makes `linkAnonymousPurchase` dead code.
    ///
    /// It also closes the analytics gap accepted at
    /// `RevenueCatManager.swift:85-88`: RevenueCat, PostHog and Supabase now
    /// share one id from first launch, so a purchase made before account
    /// creation stitches to the onboarding and paywall events that produced it.
    private func adoptGuestIdentity(_ userId: String) {
        log("🆔 Adopting guest identity: \(userId)")
        PostHogSDK.shared.identify(userId)
        FeatureFlags.shared.refresh()

        // RevenueCat is configured in RootView's `.task`, but `AuthManager.init`
        // starts `observeAuthState()` immediately — so a cached guest session
        // can emit .initialSession before configure() has run. Touching
        // `Purchases.shared` in that window is a fatalError inside RevenueCat,
        // not a recoverable nil. Defer instead; RootView applies it right after
        // configure().
        guard Purchases.isConfigured else {
            pendingGuestRevenueCatIdentity = userId
            log("🆔 RevenueCat not configured yet — guest identity deferred")
            return
        }

        guard Purchases.shared.appUserID != userId else { return }
        RevenueCatManager.shared.setUserID(userId)
    }

    /// Applies a guest identity that was deferred because RevenueCat had not
    /// been configured yet. Called by RootView immediately after `configure()`.
    func applyPendingGuestRevenueCatIdentity() {
        guard let userId = pendingGuestRevenueCatIdentity, Purchases.isConfigured else { return }
        pendingGuestRevenueCatIdentity = nil
        guard Purchases.shared.appUserID != userId else { return }
        log("🆔 Applying deferred guest identity to RevenueCat: \(userId)")
        RevenueCatManager.shared.setUserID(userId)
    }

    private func clearSessionEverMarker(reason: String) {
        hasEverHadSession = false
        isGuestSession = false
        log("🔐 has_ever_had_session cleared — \(reason)")
    }

    /// Creates a Supabase anonymous session, but only when it is provably safe.
    ///
    /// Idempotent and safe to call repeatedly — every precondition is a guard,
    /// so redundant calls are cheap no-ops. Does not update auth state itself:
    /// `signInAnonymously()` emits `.signedIn` (verified in supabase-swift
    /// `AuthClient.swift:452-453`), and the observer handles it.
    func bootstrapGuestSessionIfNeeded() async {
        // Guard order matters. The three correctness guards come first and
        // never arm a retry: if a session exists, or this device has had one,
        // no later change of circumstances should make bootstrap correct. Only
        // the two "not right now" guards below them arm `guestBootstrapPending`.
        guard !isBootstrappingGuestSession else {
            log("🎭 Guest bootstrap skipped — already in flight")
            return
        }

        guard client.auth.currentUser == nil else {
            log("🎭 Guest bootstrap skipped — a session already exists")
            return
        }

        // THE guard. See `hasEverHadSession`. Never relax this to a live
        // session check, and never let it arm a retry.
        guard !hasEverHadSession else {
            guestBootstrapPending = false
            log("🎭 Guest bootstrap REFUSED — this device has had a session before. "
                + "Treating the empty session as a restore failure, not a new user.")
            return
        }

        // Arms a retry, because "false" here is ambiguous: the flag genuinely
        // being off is indistinguishable from `/decide` not having answered
        // yet. PostHog is configured on a detached task, so a user who taps
        // "Skip for now" quickly can reach this before flags load. Without the
        // retry armed by `observeFeatureFlagsForGuestBootstrap()`, that user
        // would silently never get a session.
        guard FeatureFlags.shared.guestSessionsEnabled else {
            log("🎭 Guest bootstrap deferred — flag off or not yet loaded (armed for retry)")
            guestBootstrapPending = true
            return
        }

        // Anonymous sign-in requires the network. Deliberately do not invent a
        // local placeholder identity to paper over this: a placeholder would
        // diverge from the real row created later, and reconciling two ids is
        // the exact problem this whole plan removes. Defer instead — this
        // function is idempotent and gets retried.
        guard NetworkMonitor.shared.isConnected else {
            log("🎭 Guest bootstrap deferred — offline (armed for retry on reconnect)")
            guestBootstrapPending = true
            return
        }

        isBootstrappingGuestSession = true
        defer { isBootstrappingGuestSession = false }

        do {
            log("🎭 Creating guest session…")
            let session = try await client.auth.signInAnonymously()
            guestBootstrapPending = false
            log("✅ Guest session created: \(session.user.id) (is_anonymous: \(session.user.isAnonymous))")
        } catch {
            // Non-fatal by design. The user continues through onboarding, which
            // is entirely local, so nothing is blocked; stay armed and retry.
            guestBootstrapPending = true
            log("❌ Guest bootstrap failed: \(error.localizedDescription) — armed for retry")
        }
    }

    /// Retries a bootstrap that was deferred (offline) or failed.
    ///
    /// Without this the offline branch above would be a dead end: the user
    /// would finish onboarding with no session and nothing would ever create
    /// one. Armed only when a bootstrap actually deferred, so this costs
    /// nothing in the normal case.
    /// Retries a bootstrap that deferred because feature flags had not loaded.
    ///
    /// Pairs with the flag guard in `bootstrapGuestSessionIfNeeded()`. Also
    /// covers the operational case of flipping the flag on mid-session.
    private func observeFeatureFlagsForGuestBootstrap() {
        FeatureFlags.shared.$guestSessionsEnabled
            .dropFirst()
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.guestBootstrapPending else { return }
                    log("🎭 Guest sessions enabled — retrying deferred bootstrap")
                    await self.bootstrapGuestSessionIfNeeded()
                }
            }
            .store(in: &cancellables)
    }

    private func observeNetworkForGuestBootstrap() {
        NetworkMonitor.shared.$isConnected
            .dropFirst()
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.guestBootstrapPending else { return }
                    log("🎭 Network restored — retrying deferred guest bootstrap")
                    await self.bootstrapGuestSessionIfNeeded()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Anonymous User Methods
    func startAnonymousOnboarding() {
        log("👻 startAnonymousOnboarding() called")

        // Kick off the guest session here rather than at launch: users who tap
        // "Create Account" on LandingView should never get a guest row. Fire and
        // forget — onboarding is entirely local (UserDefaults + PostHog), so it
        // does not need the session, and nothing before MainTabView does.
        Task { await bootstrapGuestSessionIfNeeded() }

        isLegacyAnonymousUser = true
        hasCompletedOnboarding = false
        // Persist the reset too, now that completeAnonymousOnboarding()
        // writes this key. Leaving it set from a previous pass would route a
        // relaunch mid-onboarding as if the flow were already finished.
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
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
        // Persist to the same global key `completeOnboarding()` and
        // `skipOnboarding()` write, and that `AuthManager.init` reads back at
        // launch. Without this the flag lived only in memory, so an anonymous
        // user who quit before creating an account came back with
        // `hasCompletedOnboarding == false` — RootView's
        // `isLegacyAnonymousUser && hasCompletedOnboarding` branch could never
        // match, and they restarted onboarding from the beginning.
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        // Mirror into hasCompletedQuestions so the in-memory flag is already
        // true at the moment `.signedIn` fires. AuthManager is session-scoped,
        // so this value survives the anonymous → signup transition and keeps
        // RootView's line-97 check (`!hasCompletedQuestions`) from briefly
        // routing to OnboardingView while `syncAnonymousDataToBackend` is
        // still in flight. The per-user UserDefaults key is written by the
        // sync itself after signup — this flag is in-memory only.
        hasCompletedQuestions = true
        AnonymousUserManager.shared.hasCompletedOnboarding = true

        // With a guest session the user already has a real `auth.users` row, so
        // completion has to be written against THEIR id — `checkUserQuestionStatus`
        // reads `hasCompletedQuestions_<userId>` on every launch. Without this
        // the in-memory flag is lost on relaunch and the guest is sent back
        // through onboarding forever. (Permanent accounts get these keys from
        // syncAnonymousDataToBackend at signup; guests never signed up.)
        if isGuestSession, let userId = currentUser?.id.uuidString {
            UserDefaults.standard.set(true, forKey: "hasCompletedQuestions_\(userId)")
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding_\(userId)")
            log("✅ Onboarding completion persisted for guest: \(userId)")

            // Mirror to user_metadata for the same reason completePaywallFlow()
            // does: per-user UserDefaults keys don't survive reinstall, the
            // Supabase session can.
            Task {
                do {
                    try await client.auth.update(user: UserAttributes(data: [
                        "onboarding_completed": AnyJSON.bool(true)
                    ]))
                    log("✅ Mirrored onboarding_completed=true to user_metadata (guest)")
                } catch {
                    log("⚠️ Failed to mirror onboarding_completed for guest: \(error.localizedDescription)")
                }
            }
        }

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
        // Snapshot alongside `needsLinking` — `clearAllData()` below wipes it,
        // and linkAnonymousUserPurchases can no longer read it back itself.
        let anonymousCustomerID = anonymousManager.revenueCatCustomerId
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
        // per-user flags are already set, but isLegacyAnonymousUser flag would
        // linger otherwise).
        anonymousManager.clearAllData()
        isLegacyAnonymousUser = false
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
        if needsLinking, let anonymousCustomerID {
            log("🔗 Starting RevenueCat customer linking...")
            let linkSuccess = await RevenueCatManager.shared.linkAnonymousUserPurchases(
                userId,
                anonymousCustomerID: anonymousCustomerID
            )
            if linkSuccess {
                log("✅ RevenueCat purchases successfully linked")
            } else {
                // Not fatal: the entitlement still exists in RevenueCat under
                // the anonymous customer, and Restore Purchases in Settings
                // recovers it. Logged loudly because it means a paying user
                // is currently being gated.
                log("🚨 RevenueCat purchase linking FAILED — paying user may be gated. Anonymous customer: \(anonymousCustomerID)")
            }
        } else if needsLinking {
            log("🚨 RevenueCat linking skipped — needsLinking was true but no anonymous customer id was captured")
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

    // MARK: - Second-Chance Recovery Offer
    /// Marks the one-time recovery offer as shown, regardless of outcome —
    /// the guarantee is "never present it again," not "never present it
    /// again unless they bought." `outcome` is carried into the
    /// `user_metadata` mirror purely for observability (support/debugging),
    /// not for gating.
    ///
    /// Reachable only for authenticated users: the recovery offer requires
    /// account creation + MainView first (see SubscriptionGateModifier), so
    /// unlike `completePaywallFlow()` there is no anonymous-user branch here.
    func markSecondChanceOfferShown(outcome: String) {
        log("🎁 markSecondChanceOfferShown(outcome: \(outcome)) called")
        hasSeenSecondChanceOffer = true

        guard let userId = currentUser?.id.uuidString else {
            log("⚠️ markSecondChanceOfferShown: no authenticated user — nothing to persist")
            return
        }

        let key = "hasSeenSecondChanceOffer_\(userId)"
        UserDefaults.standard.set(true, forKey: key)
        log("🎁 Second-chance offer marked shown for user: \(userId)")

        // Mirror to user_metadata so this survives uninstall+reinstall, same
        // rationale as completePaywallFlow()'s mirror above.
        Task {
            do {
                let attributes = UserAttributes(data: [
                    "second_chance_offer_shown": AnyJSON.bool(true),
                    "second_chance_offer_shown_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date())),
                    "second_chance_offer_outcome": AnyJSON.string(outcome)
                ])
                try await client.auth.update(user: attributes)
                log("✅ Mirrored second_chance_offer_shown=true to user_metadata")
            } catch {
                log("⚠️ Failed to mirror second_chance_offer_shown to user_metadata: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Free Demo
    /// Called when the mascot walkthrough finishes — the user has spent their
    /// one free scenario and one free lesson. Flipping this ends demo mode and
    /// routes RootView straight into the post-demo ask, which is the peak-intent
    /// moment the whole walkthrough exists to set up.
    ///
    /// Same persistence shape as `markSecondChanceOfferShown`: per-user
    /// UserDefaults as the device source of truth, best-effort `user_metadata`
    /// mirror so a reinstall doesn't hand out a second demo.
    func markFreeDemoCompleted() {
        log("🎓 markFreeDemoCompleted() called")
        hasCompletedFreeDemo = true

        guard let userId = currentUser?.id.uuidString else {
            log("⚠️ markFreeDemoCompleted: no authenticated user — nothing to persist")
            return
        }

        let key = "hasCompletedFreeDemo_\(userId)"
        UserDefaults.standard.set(true, forKey: key)
        log("🎓 Free demo marked completed for user: \(userId)")

        Task {
            do {
                let attributes = UserAttributes(data: [
                    "free_demo_completed": AnyJSON.bool(true),
                    "free_demo_completed_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))
                ])
                try await client.auth.update(user: attributes)
                log("✅ Mirrored free_demo_completed=true to user_metadata")
            } catch {
                log("⚠️ Failed to mirror free_demo_completed to user_metadata: \(error.localizedDescription)")
            }
        }
    }

    /// Called when the user dismisses the post-demo ask without purchasing.
    /// Only reachable while the ask is soft (see `postDemoWallIsHard`) — when
    /// the wall is hard there is no dismiss affordance except the offline
    /// escape hatch, and that path deliberately does NOT call this, so the ask
    /// re-arms on the next cold start.
    func markPostDemoWallDismissed() {
        log("🚧 markPostDemoWallDismissed() called")
        hasDismissedPostDemoWall = true

        guard let userId = currentUser?.id.uuidString else {
            log("⚠️ markPostDemoWallDismissed: no authenticated user — nothing to persist")
            return
        }

        let key = "hasDismissedPostDemoWall_\(userId)"
        UserDefaults.standard.set(true, forKey: key)
        log("🚧 Post-demo wall marked dismissed for user: \(userId)")

        Task {
            do {
                let attributes = UserAttributes(data: [
                    "post_demo_wall_dismissed": AnyJSON.bool(true)
                ])
                try await client.auth.update(user: attributes)
                log("✅ Mirrored post_demo_wall_dismissed=true to user_metadata")
            } catch {
                log("⚠️ Failed to mirror post_demo_wall_dismissed to user_metadata: \(error.localizedDescription)")
            }
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

    // MARK: - Identity Linking

    /// Raised when the chosen Apple/Google identity already belongs to another
    /// Wingman account. Phase A.4 decided against building a merge flow; the
    /// only requirement is that this does not dead-end the screen.
    enum AccountLinkError: LocalizedError {
        case identityAlreadyExists

        var errorDescription: String? {
            "That account is already linked to another Wingman login. "
            + "Log in with it instead — progress from this session won't carry over."
        }
    }

    /// Exchanges an OIDC credential for a session, **preserving the current
    /// user id when the session is a guest one**.
    ///
    /// This is the piece that makes the rest of the architecture true.
    /// `signInWithIdToken` creates a *different* `auth.users` row and abandons
    /// the guest, which would:
    ///
    ///   1. strand every approach log, progress row and metadata value written
    ///      under the guest id, and
    ///   2. turn the later `RevenueCatManager.setUserID` into an
    ///      identified→identified switch, leaving a purchase made as a guest
    ///      behind on the old id — precisely the stranding documented at
    ///      `RevenueCatManager.swift:76-84`.
    ///
    /// `linkIdentityWithIdToken` attaches the provider to the *existing* row, so
    /// the id — and every foreign key, RLS row and RevenueCat entitlement keyed
    /// on it — survives untouched. There is consequently no second
    /// `Purchases.logIn` at signup and nothing to transfer.
    ///
    /// NOTE: linking emits `.userUpdated`, **not** `.signedIn` (verified in
    /// supabase-swift `AuthClient.swift:1230-1231`). The promotion from guest to
    /// permanent therefore happens in the `.userUpdated` handler.
    private func authenticate(with credentials: OpenIDConnectCredentials) async throws -> Session {
        guard isGuestSession else {
            return try await client.auth.signInWithIdToken(credentials: credentials)
        }

        log("🔗 Guest session present — linking identity rather than creating a new user")
        do {
            let session = try await client.auth.linkIdentityWithIdToken(credentials: credentials)
            log("✅ Identity linked — user id preserved: \(session.user.id)")

            // Promote here rather than relying solely on the `.userUpdated`
            // handler. That handler keys off `session.user.isAnonymous` having
            // flipped to false, which is server behaviour this project has not
            // been able to verify end-to-end (linking needs a real Apple/Google
            // flow). Calling directly means a successful link always promotes,
            // whatever the flag says. `promoteGuestToPermanent` is idempotent,
            // so whichever path runs first wins and the other no-ops.
            await promoteGuestToPermanent(session: session)
            return session
        } catch let error as AuthError where error.errorCode == .identityAlreadyExists {
            log("⚠️ Identity already attached to another account — surfacing to user")
            throw AccountLinkError.identityAlreadyExists
        }
    }

    /// Turns a guest session into a permanent-account session **in place**.
    ///
    /// Idempotent: guarded on `isGuestSession`, so the direct call in
    /// `authenticate(with:)` and the `.userUpdated` handler cannot double-apply.
    ///
    /// The user id does not change when an identity is linked, so RevenueCat and
    /// PostHog are already correct and get no second call — that invariant is
    /// the whole point of Phase D. What *is* owed are the per-user state loads,
    /// which the guest branches of `.signedIn` / `.initialSession` skip.
    /// Loads the per-user flags for a guest session.
    ///
    /// Guests hold a real `auth.users` row, so every per-user key
    /// (`hasCompletedQuestions_<id>`, `hasCompletedPaywallFlow_<id>`, the two
    /// demo flags, …) is written and read for them exactly as for a permanent
    /// account. Phase B skipped these because guests could not reach the app;
    /// from Phase E they route through the main flow and the flags decide where
    /// they land, so skipping would restart onboarding on every launch.
    private func loadGuestUserState(userId: String) async {
        await checkUserQuestionStatus(userId: userId)
        await checkUserPaywallFlowStatus(userId: userId)
        await checkUserRatingPromptStatus(userId: userId)
        await checkUserSecondChanceOfferStatus(userId: userId)
        await checkUserFreeDemoStatus(userId: userId)
        await checkUserPostDemoWallStatus(userId: userId)

        hasSeenPostPurchaseAccountAsk = UserDefaults.standard.bool(
            forKey: Self.postPurchaseAskKey(userId)
        )
        guestPromptDismissedThreshold = UserDefaults.standard.integer(
            forKey: Self.guestPromptDismissedKey(userId)
        )
        log("🔑 Guest asks — postPurchaseSeen: \(hasSeenPostPurchaseAccountAsk), "
            + "promptDismissedAt: \(guestPromptDismissedThreshold) for guest: \(userId)")
    }

    private static func postPurchaseAskKey(_ userId: String) -> String {
        "hasSeenPostPurchaseAccountAsk_\(userId)"
    }

    /// Records that the post-purchase ask was shown and declined.
    ///
    /// Called from the "Not now" path only — a successful link clears
    /// `isGuestSession`, which drops the routing condition on its own.
    func markPostPurchaseAccountAskSeen() {
        hasSeenPostPurchaseAccountAsk = true
        guard let userId = currentUser?.id.uuidString else { return }
        UserDefaults.standard.set(true, forKey: Self.postPurchaseAskKey(userId))
        log("⏭️ Post-purchase account ask marked seen for: \(userId)")

        PostHogSDK.shared.capture("account_ask_skipped", properties: ["trigger": "postPurchase"])
    }

    private func promoteGuestToPermanent(session: Session) async {
        guard isGuestSession else { return }

        let userId = session.user.id.uuidString
        log("⬆️ Guest promoted to permanent account — id preserved: \(userId)")

        isGuestSession = false
        isAuthenticated = true
        currentUser = session.user
        UserDefaults.standard.set(userId, forKey: "current_user_id")
        if let email = session.user.email, !email.isEmpty {
            UserDefaults.standard.set(email, forKey: "user_email")
        }

        await checkUserQuestionStatus(userId: userId)
        await checkUserPaywallFlowStatus(userId: userId)
        await checkUserRatingPromptStatus(userId: userId)
        await checkUserSecondChanceOfferStatus(userId: userId)
        await checkUserFreeDemoStatus(userId: userId)
        await checkUserPostDemoWallStatus(userId: userId)

        await LessonDataService.shared.hydrateLessonProgressFromCloud()

        PostHogSDK.shared.capture("account_linked", properties: [
            "method": session.user.appMetadata["provider"]?.stringValue ?? "unknown"
        ])
        FeatureFlags.shared.refresh()
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
            
            // Links to the existing guest row when there is one, otherwise a
            // plain sign-in. See `authenticate(with:)`.
            let session = try await authenticate(
                with: .init(
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

        } catch let error as AccountLinkError {
            // Phase A.4: no merge flow by decision, but the screen must not
            // dead-end — the user keeps their guest session and can try the
            // other provider or log in instead.
            isGoogleSignInLoading = false
            log("⚠️ Account link conflict: \(error.localizedDescription)")
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
            
            // Links to the existing guest row when there is one, otherwise a
            // plain sign-in. See `authenticate(with:)`.
            let session = try await authenticate(
                with: .init(
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
            
        } catch let error as AccountLinkError {
            // Phase A.4: no merge flow by decision, but the screen must not
            // dead-end — the user keeps their guest session and can try the
            // other provider or log in instead.
            isAppleSignInLoading = false
            currentNonce = nil
            appleSignInDelegate = nil
            log("⚠️ Account link conflict: \(error.localizedDescription)")
            appleSignInError = error.localizedDescription

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
            hasSeenSecondChanceOffer = false
            hasCompletedFreeDemo = false
            hasDismissedPostDemoWall = false

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

                    // RevenueCat: detach from the deleted account's identity.
                    // Server-side deletion doesn't reliably emit a Supabase
                    // .signedOut event (auth state is reset manually below),
                    // so the .signedOut handler can't be relied on here.
                    RevenueCatManager.shared.logoutUser()

                    // Update auth state
                    isAuthenticated = false
                    self.currentUser = nil
                    hasCompletedOnboarding = false
                    hasCompletedQuestions = false
                    hasCompletedPaywallFlow = false
                    hasSeenRatingPrompt = false
                    hasSeenSecondChanceOffer = false
                    hasCompletedFreeDemo = false
                    hasDismissedPostDemoWall = false
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
        userDefaults.removeObject(forKey: "hasSeenSecondChanceOffer_\(userId)")
        userDefaults.removeObject(forKey: "hasCompletedFreeDemo_\(userId)")
        userDefaults.removeObject(forKey: "hasDismissedPostDemoWall_\(userId)")
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

        // Account deletion / full local wipe is a deliberate exit, so the
        // device is allowed to bootstrap a fresh guest session afterwards.
        userDefaults.removeObject(forKey: Self.hasEverHadSessionKey)

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
