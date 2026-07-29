//
//  AuthView.swift
//  Wingman
//
//  Created by Adnan Khan on 30/11/2025.
//

import SwiftUI
import PostHog

struct AuthView: View {
    let mode: AuthMode

    /// How the user arrived here. Drives both the copy and whether backing out
    /// is allowed — see `AuthContext` and `canGoBack`.
    let context: AuthContext

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @State private var safariLink: IdentifiableURL?

    init(mode: AuthMode, context: AuthContext = .voluntary) {
        self.mode = mode
        self.context = context
        log("🎬 AuthView initialized with mode: \(mode == .signup ? "SIGNUP" : "LOGIN"), context: \(context)")
    }

    /// Controls whether the top-leading back chevron is rendered.
    ///
    /// `.voluntary` keeps it — AuthView pushed from LandingView (Create Account
    /// / Sign In) and the unauthenticated login routing branch both put the user
    /// somewhere they chose to go, so they need a way back out.
    ///
    /// `.requiredAfterPaywall` suppresses it. Without this guard, a user who
    /// already purchased (RevenueCat entitlement attached to their anonymous ID)
    /// could tap back, land on LandingView, and end up re-seeing the paywall on
    /// the next anonymous pass — a confusing "I paid, why are you asking again?"
    /// loop. Hiding the chevron there enforces the "must create an account"
    /// rule; the copy is what stops that from feeling like a trap.
    private var canGoBack: Bool { context == .voluntary }

    private var isRequiredStep: Bool { context == .requiredAfterPaywall }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Top Row: Back Chevron
            //
            // The chevron is suppressed when `canGoBack` is false (forced
            // post-paywall AuthView). A clear placeholder of the same size
            // takes its place so the title/subtitle below sit at the same
            // vertical position regardless of which mode this AuthView is in.
            HStack(spacing: 12) {
                if canGoBack {
                    Button {
                        handleBackButton()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22))
                            .foregroundColor(.wingmanBlack)
                            .frame(width: 44, height: 44, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(ScalePressStyle())
                    .disabled(authManager.isGoogleSignInLoading || authManager.isAppleSignInLoading)
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }

                Spacer()
            }
            .padding(.top, 8)
            .padding(.leading, 8)
            .padding(.bottom, 12)

            // On the required screen the content block is optically centred
            // between the top row and the legal footer instead of being pinned
            // to the top with half a screen of white below it. Voluntary
            // presentations keep their original top-aligned layout.
            if isRequiredStep {
                Spacer(minLength: 0)
            }

            // MARK: - Header (Title + Subtitle) - DYNAMIC BASED ON CONTEXT
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(headerTitle)
                        .font(.manropeSemiBold(size: 32))
                        .foregroundColor(.wingmanBlack)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(headerSubtitle)
                        .font(.manropeRegular(size: 16))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 40)

            // MARK: - Social Sign-In Buttons
            VStack(spacing: 13) {
                outlineButton(
                    title: authManager.isAppleSignInLoading ? "Signing in..." : "Continue with Apple",
                    imageName: "auth_apple_logo",
                    isLoading: authManager.isAppleSignInLoading
                ) {
                    HapticManager.shared.mediumImpact()
                    authManager.signInWithApple()
                }
                .disabled(authManager.isAppleSignInLoading || authManager.isGoogleSignInLoading)
                .shadow(color: Color.wingmanBlack.opacity(0.06), radius: 5, x: 0, y: 2)

                outlineButton(
                    title: authManager.isGoogleSignInLoading ? "Signing in..." : "Continue with Google",
                    imageName: "auth_google_logo",
                    isLoading: authManager.isGoogleSignInLoading
                ) {
                    HapticManager.shared.mediumImpact()
                    Task {
                        await authManager.signInWithGoogle()
                    }
                }
                .disabled(authManager.isGoogleSignInLoading || authManager.isAppleSignInLoading)
                .shadow(color: Color.wingmanBlack.opacity(0.06), radius: 5, x: 0, y: 2)
            }
            .padding(.horizontal, 20)

            // MARK: - Error Messages
            if let error = authManager.appleSignInError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 12)
                    .padding(.horizontal, 20)
            }

            if let error = authManager.googleSignInError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.top, 12)
                    .padding(.horizontal, 20)
            }

            // MARK: - Destination Reassurance (required step only)
            //
            // The third job of this screen's copy: say what is on the other
            // side. Verified against RootView — a user who reaches this screen
            // dismissed paywall #1, so `reachedPaywallEndState` is true and
            // `syncAnonymousDataToBackend()` transfers hasCompletedOnboarding /
            // hasCompletedQuestions / hasCompletedPaywallFlow / hasSeenRatingPrompt
            // to the per-user keys before any network await. Signing in here
            // therefore lands on MainTabView with no further gates. If that
            // routing ever changes, this line has to change with it.
            if isRequiredStep {
                Text("Nothing else to set up — you'll go straight into the app.")
                    .font(.manropeRegular(size: 14))
                    .foregroundColor(Color.wingmanBlack.opacity(0.5))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
            }

            Spacer()

            // MARK: - Legal Footer (required step only)
            //
            // This is the one screen in the flow the user cannot decline, which
            // is exactly where explicit consent belongs. It also gives the
            // bottom of the screen a purpose instead of leaving it blank.
            if isRequiredStep {
                legalFooter
            }
        }
        .navigationBarBackButtonHidden(true)
        .enableInteractivePopGesture()
        .sheet(item: $safariLink) { SafariView(url: $0.url) }
        .onAppear {
            log("👁️ AuthView appeared")
        }
        .onDisappear {
            log("👋 AuthView disappeared")
        }
        .padding(.top, 8)
        // Session replay: mask the whole auth screen. maskAllTextInputs
        // already covers what's typed into the fields, but this also keeps a
        // signed-in email out of the replay if the screen ever renders one.
        .postHogMask()
        // Split the required screen out from the voluntary one. They had the
        // same name, which made the post-paywall drop-off impossible to isolate
        // in a funnel — the whole reason this screen was hard to diagnose.
        // NOTE: "Auth" therefore means something narrower from this build on;
        // historical "Auth" series include both screens.
        .postHogScreenView(isRequiredStep ? "AuthRequired" : "Auth")
    }

    // MARK: - Handle Back Button
    private func handleBackButton() {
        log("⬅️ Back button: Dismissing AuthView (returning to LandingView)")
        authManager.resetOnboarding()
        dismiss()
    }

    // MARK: - Computed Properties for Dynamic Text
    //
    // The required-step copy splits three jobs that the voluntary copy doesn't
    // have to do, because a voluntary visitor already knows why they're here:
    //
    //   headerTitle    — how many more gates? ("One last step")
    //   headerSubtitle — why does this account exist, and what does it cost?
    //   the footnote below the buttons — what's on the other side?
    //
    // Kept as three separate lines on purpose. Collapsing them into one
    // sentence is what produced the original "Save your progress, sync across
    // devices" — true, but it answers a question the user isn't asking while
    // ignoring the one they are.
    private var headerTitle: String {
        switch context {
        case .requiredAfterPaywall:
            return "One last step"
        case .voluntary:
            return mode == .signup ? "Create Account" : "Welcome Back"
        }
    }

    private var headerSubtitle: String {
        switch context {
        case .requiredAfterPaywall:
            // "free" is doing real work here: this screen lands seconds after a
            // dismissed paywall, and the default reading is "another thing to
            // pay for." It is also literally accurate — the account costs
            // nothing; the subscription gates content later.
            return "Create a free account so your answers and progress are saved."
        case .voluntary:
            return "Save your progress, sync across devices, and more."
        }
    }

    // MARK: - Legal Footer
    private var legalFooter: some View {
        HStack(spacing: 4) {
            Text("By continuing you agree to our")
                .foregroundColor(Color.wingmanBlack.opacity(0.45))

            Button {
                if let url = URL(string: Constants.TERMS_CONDITIONS_URL) {
                    safariLink = IdentifiableURL(url: url)
                }
            } label: {
                Text("Terms")
                    .foregroundColor(Color.wingmanBlack.opacity(0.7))
                    .underline()
            }
            .buttonStyle(ScalePressStyle())

            Text("and")
                .foregroundColor(Color.wingmanBlack.opacity(0.45))

            Button {
                if let url = URL(string: Constants.PRIVACY_POLICY_URL) {
                    safariLink = IdentifiableURL(url: url)
                }
            } label: {
                Text("Privacy")
                    .foregroundColor(Color.wingmanBlack.opacity(0.7))
                    .underline()
            }
            .buttonStyle(ScalePressStyle())
        }
        .font(.manropeRegular(size: 12))
        .multilineTextAlignment(.center)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }

    // MARK: - Outline Button
    private func outlineButton(title: String, imageName: String = "", isLoading: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else {
                    if !imageName.isEmpty {
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    }
                    Text(title)
                        .fontWeight(.medium)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundColor(.wingmanBlack)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.gray.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(ScalePressStyle())
    }
}

#Preview("Signup") {
    AuthView(mode: .signup)
        .environmentObject(AuthManager())
}

#Preview("Login") {
    AuthView(mode: .login)
        .environmentObject(AuthManager())
}

#Preview("Required after paywall") {
    AuthView(mode: .signup, context: .requiredAfterPaywall)
        .environmentObject(AuthManager())
}
