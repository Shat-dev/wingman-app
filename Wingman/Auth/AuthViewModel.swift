//
//  AuthViewModel.swift
//  Wingman
//
//  Created by Adnan Khan on 30/11/2025.
//

import Foundation
import Combine
import Auth
import Supabase

final class AuthViewModel: ObservableObject {

    // MARK: - Mode
    let mode: AuthMode

    // MARK: - Inputs
    @Published var email: String = ""
    @Published var password: String = ""

    // MARK: - UI State
    @Published var currentStep: AuthStep = .email
    @Published var isLoading: Bool = false

    // MARK: - Validation
    @Published var isEmailValid: Bool = false
    @Published var emailErrorMessage: String = ""

    @Published var isPasswordValid: Bool = false
    @Published var passwordErrorMessage: String = ""

    @Published var emailTouched: Bool = false
    @Published var passwordTouched: Bool = false

    private var cancellables = Set<AnyCancellable>()

    enum AuthStep {
        case email
        case password
        case complete
    }

    // MARK: - Init
    init(mode: AuthMode) {
        self.mode = mode
        print("🔧 AuthViewModel initialized with mode: \(mode == .signup ? "SIGNUP" : "LOGIN")")
        setupEmailValidation()
        setupPasswordValidation()
    }

    // MARK: - Email Validation
    private func setupEmailValidation() {
        $email
            .debounce(for: .milliseconds(400), scheduler: RunLoop.main)
            .sink { [weak self] email in
                guard let self = self else { return }

                if !self.emailTouched {
                    self.emailErrorMessage = ""
                    self.isEmailValid = false
                    return
                }

                if email.isEmpty {
                    self.emailErrorMessage = "Email cannot be empty"
                    self.isEmailValid = false
                } else if !self.isValidEmail(email) {
                    self.emailErrorMessage = "Please enter a valid email address"
                    self.isEmailValid = false
                } else {
                    self.emailErrorMessage = ""
                    self.isEmailValid = true
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Password Validation
    private func setupPasswordValidation() {
        $password
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] password in
                guard let self = self else { return }

                if !self.passwordTouched {
                    self.passwordErrorMessage = ""
                    self.isPasswordValid = false
                    return
                }

                if password.isEmpty {
                    self.passwordErrorMessage = "Password cannot be empty"
                    self.isPasswordValid = false
                } else if password.count < 6 {
                    self.passwordErrorMessage = "Password must be at least 6 characters"
                    self.isPasswordValid = false
                } else {
                    self.passwordErrorMessage = ""
                    self.isPasswordValid = true
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions
    func continueToPassword() {
        emailTouched = true
        guard isEmailValid else { return }
        print("📧 Email validated, moving to password step")
        currentStep = .password
    }

    func goBackToEmail() {
        print("⬅️ Going back to email step")
        currentStep = .email
    }

    // MARK: - Supabase Submit (LOGIN + SIGNUP)
    // LINE WHERE ACCOUNT CREATION/LOGIN HAPPENS
    func submit() {
        print("\n🚀 ========== SUBMIT CALLED ==========")
        print("📝 Mode: \(mode == .signup ? "SIGNUP" : "LOGIN")")
        print("📧 Email: \(email)")
        
        passwordTouched = true
        guard isEmailValid && isPasswordValid else {
            print("❌ Validation failed")
            return
        }

        isLoading = true
        print("⏳ Loading started...")

        Task {
            do {
                if mode == .signup {
                    // LINE 145-148: SIGNUP HAPPENS HERE
                    print("\n📤 Sending SIGNUP request to Supabase...")
                    let response = try await SupabaseManager.shared.client.auth.signUp(
                        email: email,
                        password: password
                    )
                    print("✅ SIGNUP Response received:")
                    print("   - User ID: \(response.user.id)")
                    print("   - Email: \(response.user.email ?? "nil")")
                    //print("   - Access Token exists: \(response.accessToken.isEmpty ? "NO" : "YES")")
                    print("   - Session type: \(type(of: response))")
                    
                } else {
                    // LINE 158-161: LOGIN HAPPENS HERE
                    print("\n📤 Sending LOGIN request to Supabase...")
                    let response = try await SupabaseManager.shared.client.auth.signIn(
                        email: email,
                        password: password
                    )
                    print("✅ LOGIN Response received:")
                    print("   - User ID: \(response.user.id)")
                    print("   - Email: \(response.user.email ?? "nil")")
                    print("   - Access Token exists: \(response.accessToken.isEmpty ? "NO" : "YES")")
                    print("   - Session type: \(type(of: response))")
                }

                // LINE 170-174: NAVIGATION TO .complete HAPPENS HERE
                await MainActor.run {
                    self.isLoading = false
                    print("✅ Setting currentStep to .complete")
                    self.currentStep = .complete
                    print("🎯 Current step is now: \(self.currentStep)")
                }

            } catch {
                print("\n❌ ========== ERROR ==========")
                print("❌ Error type: \(type(of: error))")
                print("❌ Error description: \(error.localizedDescription)")
                print("❌ Full error: \(error)")
                
                await MainActor.run {
                    self.isLoading = false
                    self.passwordErrorMessage = error.localizedDescription
                    print("❌ Error message set: \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Helpers
    private func isValidEmail(_ email: String) -> Bool {
        let regex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return NSPredicate(format: "SELF MATCHES %@", regex)
            .evaluate(with: email)
    }
}
