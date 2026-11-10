//
//  OnboardingView.swift
//  Wingman
//
//  Created by Adnan Khan on 29/11/2025.
//

import SwiftUI
import PostHog

struct LandingView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var navigateToLogin = false
    @State private var navigateToOnboarding = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // MARK: - Hero
                //
                // One screen instead of the old four-slide feature carousel:
                // the image shows the gap (the life he imagines vs. the woman
                // walking past) and the copy turns it into a promise, so the
                // only thing left to do here is tap the button.
                VStack(alignment: .leading, spacing: 12) {
                    Text("Turn \u{201C}what if\u{201D} into \u{201C}hi.\u{201D}")
                        .font(.manropeSemiBold(size: 32))
                        .foregroundColor(.wingmanBlack)

                    Text("The step-by-step way to stop freezing up and start the conversation.")
                        .font(.manropeRegular(size: 16))
                        .foregroundColor(Color.wingmanBlack.opacity(0.5))
                        .lineSpacing(3)
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 64)

                // The image sits centred in whatever height is left between
                // the copy and the buttons.
                Spacer(minLength: 16)

                Image("landing_what_if")
                    .resizable()
                    .scaledToFit()
                    .padding(.horizontal, 8)
                    .accessibilityLabel("A man watches a woman walk past, imagining them together")

                Spacer(minLength: 16)

                // MARK: - CTA Buttons
                VStack(spacing: 20) {

                    // MARK: - Primary CTA — start without an account
                    //
                    // This is the majority path now that guest sessions exist,
                    // so it gets the primary treatment. It previously sat at the
                    // bottom as a small underlined "Skip for now" while Log In
                    // took the filled button — a hierarchy that made the least
                    // common action (logging in) the most prominent one, and
                    // buried the route most users should take.
                    //
                    // "Get started" rather than "Skip for now" or "Continue as
                    // guest": "skip" frames the account as a deferred obligation
                    // and primes the user to expect nagging (and is now simply
                    // untrue — nothing walls them later), while "guest" implies
                    // a second-class mode. Naming the destination says what
                    // happens next and implies nothing about accounts, which is
                    // right, because accounts are genuinely optional.
                    Button {
                        HapticManager.shared.tapStrong()
                        log("🔘 Get started button tapped")
                        authManager.startAnonymousOnboarding()
                        navigateToOnboarding = true
                    } label: {
                        Text("Get started")
                            .font(.manropeSemiBold(size: 16))
                            .foregroundColor(.wingmanWhiteFF)
                            .frame(maxWidth: .infinity)
                            .labelHeight(52)
                            .background(Color.wingmanBlack)
                            .cornerRadius(5)
                    }
                    .buttonStyle(ScalePressStyle())
                    .navigationDestination(isPresented: $navigateToOnboarding) {
                        OnboardingView(showLanding: $navigateToOnboarding)
                    }

                    // MARK: - Returning users
                    //
                    // Demoted to a text link. "Create Account" is deliberately
                    // gone from this screen: an account is now offered after
                    // purchase and from Profile, at moments where it justifies
                    // itself, rather than being demanded from someone who has
                    // not seen the product yet. Sign-up is still reachable —
                    // AuthView(.signup) is presented from both of those places.
                    Button {
                        HapticManager.shared.tapStrong()
                        navigateToLogin = true
                    } label: {
                        HStack(spacing: 4) {
                            Text("Already have an account?")
                                .foregroundColor(Color.wingmanBlack.opacity(0.55))
                            Text("Log in")
                                .foregroundColor(Color.wingmanBlack)
                                .underline()
                        }
                        .font(.manropeSemiBold(size: 15))
                        .frame(maxWidth: .infinity)
                        .labelHeight(44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(ScalePressStyle())
                    .navigationDestination(isPresented: $navigateToLogin) {
                        AuthView(mode: .login)
                    }
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 10)
            }
            // Note: Dynamic Type is clamped app-wide at the root
            // (WingmanApp → RootView), which covers this screen, so no
            // per-screen clamp is needed here.
        }
        .onChange(of: navigateToOnboarding) { newValue in
            log("📊 LandingView: navigateToOnboarding changed to: \(newValue)")
        }
        .trackScreenView(Analytics.Screen.landing)
    }
}


#Preview {
    LandingView()
        .environmentObject(AuthManager())
}
