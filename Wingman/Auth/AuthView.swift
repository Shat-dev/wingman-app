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
        @StateObject private var viewModel: AuthViewModel
        @FocusState private var focusedField: Field?

        enum Field {
            case email, password
        }

        init(mode: AuthMode) {
            self.mode = mode
            _viewModel = StateObject(wrappedValue: AuthViewModel(mode: mode))
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
                    if viewModel.currentStep == .password {
                        viewModel.goBackToEmail()
                    } else {
                        // Dismiss or handle navigation back if embedded in a stack
                        dismiss()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44, alignment: .center)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                // Progress bar should expand to fill remaining width
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
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    
                    Text(headerSubtitle)
                        .font(.body)
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
                    
                    // Continue Button - Filled Primary
                    filledButton(title: "Continue", isEnabled: viewModel.isEmailValid) {
                        viewModel.continueToPassword()
                    }
                    
                    // Divider with "or" like Figma
                    orDivider()
                        .padding(.vertical, 8)
                    
                    // Social Login Buttons - Outline Secondary
                    VStack(spacing: 12) {
                        outlineButton(title: "Continue with Google", systemImage: "g.circle.fill") {
                            // Handle Google login
                        }
                        
                        outlineButton(title: "Continue with Apple", systemImage: "applelogo") {
                            // Handle Apple login
                        }
                    }
                    
                } else if viewModel.currentStep == .password {
                    inputField(title: "Password", text: $viewModel.password, errorMessage: viewModel.passwordErrorMessage, isSecure: true, focused: .password)
                    
                    // Primary Action Button - Dynamic Text Based on Mode
                    filledButton(title: primaryButtonTitle, isEnabled: viewModel.isPasswordValid) {
                        viewModel.submit()
                    }
                    
                    // Back Button - Outline Secondary
                    outlineButton(title: "Back") {
                        viewModel.goBackToEmail()
                    }
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
        // Hide system back button if embedded in NavigationStack/NavigationView
        .navigationBarBackButtonHidden(true)
        // If presented as a sheet and you want to prevent drag-to-dismiss, uncomment:
        // .interactiveDismissDisabled(true)
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
        .onChange(of: viewModel.currentStep) { newStep in
            focusedField = {
                switch newStep {
                case .email: return .email
                case .password: return .password
                case .complete: return nil
                }
            }()
        }
        .onAppear {
            focusedField = .email
        }
        .padding(.top, 8)
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
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
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
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
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

    // MARK: - Filled Button (Primary like Create Account on onboarding)
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
                    .cornerRadius(10)
            }
        }
        .disabled(!isEnabled || viewModel.isLoading)
    }
    
    // MARK: - Outline Button (Secondary like Login on onboarding)
    private func outlineButton(title: String, systemImage: String = "", action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if !systemImage.isEmpty {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .foregroundColor(.black)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.6), lineWidth: 1)
            )
        }
    }
}

#Preview("Signup") {
    AuthView(mode: .signup)
}

#Preview("Login") {
    AuthView(mode: .login)
}
