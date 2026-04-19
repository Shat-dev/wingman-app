//
//  AuthView.swift
//  Wingman
//
//  Created by Adnan Khan on 30/11/2025.
//

import SwiftUI

struct AuthView: View {
    let mode: AuthMode

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    init(mode: AuthMode) {
        self.mode = mode
        log("🎬 AuthView initialized with mode: \(mode == .signup ? "SIGNUP" : "LOGIN")")
    }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Top Row: Back Chevron
            HStack(spacing: 12) {
                Button {
                    handleBackButton()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22))
                        .foregroundColor(.wingmanBlack)
                        .frame(width: 44, height: 44, alignment: .center)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(authManager.isGoogleSignInLoading || authManager.isAppleSignInLoading)

                Spacer()
            }
            .padding(.top, 8)
            .padding(.leading, 8)
            .padding(.bottom, 12)

            // MARK: - Header (Title + Subtitle) - DYNAMIC BASED ON MODE
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(headerTitle)
                        .font(.manropeSemiBold(size: 32))
                        .foregroundColor(.wingmanBlack)

                    Text(headerSubtitle)
                        .font(.manropeRegular(size: 16))
                        .foregroundColor(.secondary)
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

            Spacer()
        }
        .navigationBarBackButtonHidden(true)
        .enableInteractivePopGesture()
        .onAppear {
            log("👁️ AuthView appeared")
        }
        .onDisappear {
            log("👋 AuthView disappeared")
        }
        .padding(.top, 8)
    }

    // MARK: - Handle Back Button
    private func handleBackButton() {
        log("⬅️ Back button: Dismissing AuthView (returning to LandingView)")
        authManager.resetOnboarding()
        dismiss()
    }

    // MARK: - Computed Properties for Dynamic Text
    private var headerTitle: String {
        return mode == .signup ? "Create Account" : "Welcome Back"
    }

    private var headerSubtitle: String {
        return "Save your progress, sync across devices, and more."
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
