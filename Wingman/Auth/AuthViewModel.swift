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
        currentStep = .password
    }

    func goBackToEmail() {
        currentStep = .email
    }

    // MARK: - Supabase Submit (LOGIN + SIGNUP)
    func submit() {
        passwordTouched = true
        guard isEmailValid && isPasswordValid else { return }

        isLoading = true

        Task {
            do {
                if mode == .signup {
                    try await SupabaseManager.shared.client.auth.signUp(
                        email: email,
                        password: password
                    )
                } else {
                    try await SupabaseManager.shared.client.auth.signIn(
                        email: email,
                        password: password
                    )
                }

                await MainActor.run {
                    self.isLoading = false
                    self.currentStep = .complete
                }

            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.passwordErrorMessage = error.localizedDescription
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
