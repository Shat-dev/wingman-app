//
//  AuthView.swift
//  Wingman
//
//  Created by Adnan Khan on 30/11/2025.
//

import SwiftUI
import Combine

struct AuthView: View {
    let mode: AuthMode

        @Environment(\.dismiss) private var dismiss
        @EnvironmentObject var authManager: AuthManager
        @StateObject private var viewModel: AuthViewModel
        @FocusState private var focusedField: Field?
        
        @State private var isWaitingForAuth = false
        @State private var showSignupSuccessMessage = false

        enum Field {
            case email, password
        }

        init(mode: AuthMode) {
            self.mode = mode
            _viewModel = StateObject(wrappedValue: AuthViewModel(mode: mode))
            print("🎬 AuthView initialized with mode: \(mode == .signup ? "SIGNUP" : "LOGIN")")
        }
    
    // Computed progress for the top bar (email -> 0.5, password -> 1.0, complete -> 1.0)
    private var progress: CGFloat {
        switch viewModel.currentStep {
        case .email: return 0.5
        case .password, .complete: return 1.0
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            
            // MARK: - Top Row: Back Chevron + Progress Bar inline
            HStack(spacing: 12) {
                Button {
                    handleBackButton()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44, alignment: .center)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isWaitingForAuth) // Disable during auth wait
                
                progressBar(progress: progress)
                    .frame(height: 10)
            }
            .padding(.top, 8)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            
            // MARK: - Header (Title + Subtitle) - DYNAMIC BASED ON MODE
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(headerTitle)
                        .font(.manropeSemiBold(size: 28))
                        .foregroundColor(.black)
                    
                    Text(headerSubtitle)
                        .font(.manropeRegular(size: 16))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
            }
            .padding(.top, 4)
            .padding(.bottom, 24)
            
            // MARK: - Form
            VStack(spacing: 12) {
                if viewModel.currentStep == .email {
                    inputField(title: "Email", text: $viewModel.email, errorMessage: viewModel.emailErrorMessage, isSecure: false, focused: .email)
                    
                    filledButton(title: "Continue", isEnabled: viewModel.isEmailValid) {
                        viewModel.continueToPassword()
                    }
                    
                    orDivider()
                        .padding(.vertical, 8)
                    
                    VStack(spacing: 12) {
                        outlineButton(
                            title: authManager.isGoogleSignInLoading ? "Signing in..." : "Continue with Google",
                            systemImage: "g.circle.fill",
                            isLoading: authManager.isGoogleSignInLoading
                        ) {
                            Task {
                                await authManager.signInWithGoogle()
                            }
                        }
                        .disabled(authManager.isGoogleSignInLoading)
                        
                        outlineButton(
                            title: authManager.isAppleSignInLoading ? "Signing in..." : "Continue with Apple",
                            systemImage: "apple.logo",
                            isLoading: authManager.isAppleSignInLoading
                        ) {
                            authManager.signInWithApple()
                        }
                        .disabled(authManager.isAppleSignInLoading)
                    }
                    
                    // Show Google Sign-In error if any
                    if let error = authManager.googleSignInError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                    
                    // Show Apple Sign-In error if any
                    if let error = authManager.appleSignInError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                    
                } else if viewModel.currentStep == .password {
                    inputField(title: "Password", text: $viewModel.password, errorMessage: viewModel.passwordErrorMessage, isSecure: true, focused: .password)
                    
                    filledButton(title: primaryButtonTitle, isEnabled: viewModel.isPasswordValid) {
                        viewModel.submit()
                    }
                    
                    outlineButton(title: "Back") {
                        viewModel.goBackToEmail()
                    }
                    
                } else if viewModel.currentStep == .complete {
                    // Show waiting state
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                        
                        Text("Setting up your account...")
                            .font(.manropeRegular(size: 16))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        .navigationBarBackButtonHidden(true)
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
        // LINE 125-145: HANDLES STEP CHANGES AND TRIGGERS ONBOARDING COMPLETION
        .onChange(of: viewModel.currentStep) { newStep in
            print("\n📍 AuthView: currentStep changed to: \(newStep)")
            
            focusedField = {
                switch newStep {
                case .email: return .email
                case .password: return .password
                case .complete: return nil
                }
            }()
            
            // LINE 137: When auth is complete, mark onboarding as done and wait for auth
            if newStep == .complete {
                print("✅ AuthView: Auth complete! Calling authManager.completeOnboarding()")
                authManager.completeOnboarding()
                isWaitingForAuth = true
                
                print("📊 Current auth state:")
                print("   - isAuthenticated: \(authManager.isAuthenticated)")
                print("   - hasCompletedOnboarding: \(authManager.hasCompletedOnboarding)")
                print("   - hasCompletedQuestions: \(authManager.hasCompletedQuestions)")
                
                // For signup mode, show success message
                if viewModel.mode == .signup {
                    // Wait briefly then show success message
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second
                        await MainActor.run {
                            showSignupSuccessMessage = true
                        }
                        
                        // Auto-dismiss after 2.5 seconds
                        try? await Task.sleep(nanoseconds: 2_500_000_000) // 2.5 seconds
                        await MainActor.run {
                            showSignupSuccessMessage = false
                            // Navigation will happen automatically via RootView
                        }
                    }
                }
                
                // Wait for auth state to update (max 5 seconds)
                Task {
                    for i in 1...50 {
                        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
                        if authManager.isAuthenticated {
                            print("✅ Auth state updated after \(i * 100)ms")
                            break
                        }
                    }
                    
                    if !authManager.isAuthenticated {
                        print("⚠️ WARNING: Auth state didn't update after 5 seconds")
                        print("⚠️ This might be an email confirmation issue in Supabase")
                    }
                }
            }
        }
        .onAppear {
            print("👁️ AuthView appeared")
            focusedField = .email
        }
        .onDisappear {
            print("👋 AuthView disappeared")
        }
        .padding(.top, 8)
        .overlay(
            // SUCCESS MESSAGE OVERLAY
            Group {
                if showSignupSuccessMessage {
                    ZStack {
                        // Semi-transparent background
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                        
                        // Success card
                        VStack(spacing: 16) {
                            // Success icon
                            ZStack {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 60, height: 60)
                                
                                Image(systemName: "checkmark")
                                    .font(.system(size: 30, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            
                            // Success message
                            VStack(spacing: 8) {
                                Text("Signup Successful!")
                                    .font(.manropeSemiBold(size: 22))
                                    .foregroundColor(.black)
                                
                                Text("Please login to continue")
                                    .font(.manropeRegular(size: 16))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
                        )
                        .padding(.horizontal, 40)
                    }
                    .transition(.asymmetric(
                        insertion: .scale.combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: showSignupSuccessMessage)
        )
    }
    
    // MARK: - Handle Back Button
    private func handleBackButton() {
        if viewModel.currentStep == .complete {
            print("⚠️ Back button pressed during auth completion - ignoring")
            return
        }
        
        if viewModel.currentStep == .password {
            print("⬅️ Back button: Going to email step")
            viewModel.goBackToEmail()
        } else {
            print("⬅️ Back button: Dismissing AuthView (returning to LandingView)")
            // Reset onboarding so user goes back to Landing
            authManager.resetOnboarding()
            dismiss()
        }
    }
    
    // MARK: - Computed Properties for Dynamic Text
    private var headerTitle: String {
        if viewModel.mode == .signup {
            return viewModel.currentStep == .email ? "Create Account" : "Set a Password"
        } else {
            return viewModel.currentStep == .email ? "Login" : "Enter Password"
        }
    }
    
    private var headerSubtitle: String {
        if viewModel.currentStep == .email {
            return "Save your progress, sync across devices, and more."
        } else {
            return "Your password needs to be at least 6 characters."
        }
    }
    
    private var primaryButtonTitle: String {
        return viewModel.mode == .signup ? "Create Account" : "Login"
    }
    
    // MARK: - Progress Bar View
    private func progressBar(progress: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 10)

                Capsule()
                    .fill(Color.black)
                    .frame(width: geo.size.width * progress, height: 10)
                    .animation(.easeInOut(duration: 0.25), value: progress)
            }
        }
        .frame(height: 10)
    }
    
    // MARK: - OR Divider
    private func orDivider() -> some View {
        HStack(alignment: .center, spacing: 12) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
            Text("or")
                .foregroundColor(.gray)
                .font(.subheadline)
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
        }
    }
    
    // MARK: - Input Field
    private func inputField(title: String, text: Binding<String>, errorMessage: String, isSecure: Bool, focused: Field) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if isSecure {
                SecureField("Enter your \(title.lowercased())", text: text)
                    .focused($focusedField, equals: focused)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(5)
                    .font(.manropeRegular(size: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(errorMessage.isEmpty ? Color.clear : Color.red, lineWidth: 1)
                    )
                    .onChange(of: text.wrappedValue) { _ in
                        viewModel.passwordTouched = true
                    }
            } else {
                TextField("Enter your \(title.lowercased())", text: text)
                    .keyboardType(title.lowercased() == "email" ? .emailAddress : .default)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: focused)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(5)
                    .font(.manropeRegular(size: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(errorMessage.isEmpty ? Color.clear : Color.red, lineWidth: 1)
                    )
                    .onChange(of: text.wrappedValue) { _ in
                        viewModel.emailTouched = true
                    }
            }
            
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Filled Button
    private func filledButton(title: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                Text(title)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .foregroundColor(.white)
                    .background(isEnabled ? Color.black : Color.gray.opacity(0.5))
                    .cornerRadius(5)
            }
        }
        .disabled(!isEnabled || viewModel.isLoading)
    }
    
    // MARK: - Outline Button
    private func outlineButton(title: String, systemImage: String = "", isLoading: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                } else {
                    if !systemImage.isEmpty {
                        Image(systemName: systemImage)
                    }
                    Text(title)
                        .fontWeight(.medium)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundColor(.black)
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
