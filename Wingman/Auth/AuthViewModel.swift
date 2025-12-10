//
//  AuthViewModel.swift
//  Wingman
//
//  Created by Adnan Khan on 30/11/2025.
//

import Foundation
import Combine


class AuthViewModel: ObservableObject {
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var currentStep: AuthStep = .email
    @Published var isLoading: Bool = false
    
    // Validation states
    @Published var isEmailValid: Bool = false
    @Published var emailErrorMessage: String = ""
    @Published var isPasswordValid: Bool = false
    @Published var passwordErrorMessage: String = ""
    
    // Track if user has interacted with the fields
    @Published var emailTouched: Bool = false
    @Published var passwordTouched: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    enum AuthStep {
        case email
        case password
        case complete
    }
    
    init() {
        setupEmailValidation()
        setupPasswordValidation()
    }
    
    private func setupEmailValidation() {
        $email
            .debounce(for: 0.5, scheduler: RunLoop.main)
            .map { [weak self] email in
                guard let self = self else { return ("") }
                
                // Only show error if user touched the field
                guard self.emailTouched else { return ("") }
                
                if email.isEmpty {
                    return ("Email cannot be empty")
                } else if !self.isValidEmail(email) {
                    return ("Please enter a valid email address")
                } else {
                    return ("")
                }
            }
            .assign(to: \.emailErrorMessage, on: self)
            .store(in: &cancellables)
        
        $email
            .map { [weak self] email in
                guard let self = self else { return false }
                return !email.isEmpty && self.isValidEmail(email)
            }
            .assign(to: \.isEmailValid, on: self)
            .store(in: &cancellables)
    }
    
    private func setupPasswordValidation() {
        $password
            .debounce(for: 0.3, scheduler: RunLoop.main)
            .map { [weak self] password in
                guard let self = self else { return ("") }
                
                // Only show error if user touched the field
                guard self.passwordTouched else { return ("") }
                
                if password.isEmpty {
                    return ("Password cannot be empty")
                } else if password.count < 6 {
                    return ("Password must be at least 6 characters")
                } else {
                    return ("")
                }
            }
            .assign(to: \.passwordErrorMessage, on: self)
            .store(in: &cancellables)
        
        $password
            .map { password in
                !password.isEmpty && password.count >= 6
            }
            .assign(to: \.isPasswordValid, on: self)
            .store(in: &cancellables)
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPred = NSPredicate(format:"SELF MATCHES %@", emailRegEx)
        return emailPred.evaluate(with: email)
    }
    
    func continueToPassword() {
        // Mark email as touched before validation
        emailTouched = true
        
        guard isEmailValid else { return }
        currentStep = .password
    }
    
    func createAccount() {
        // Mark password as touched before validation
        passwordTouched = true
        
        guard isEmailValid && isPasswordValid else { return }
        
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isLoading = false
            self.currentStep = .complete
        }
    }
    
    func goBackToEmail() {
        currentStep = .email
    }
}
