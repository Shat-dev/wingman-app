//
//  AuthService.swift
//  Wingman
//
//  Created by Adnan Khan on 14/12/2025.
//


import Foundation
import Supabase
import Auth

final class AuthService {

    private let client = SupabaseManager.shared.client

    func signUp(email: String, password: String) async throws {
        try await client.auth.signUp(
            email: email,
            password: password
        )
    }

    func login(email: String, password: String) async throws {
        try await client.auth.signIn(
            email: email,
            password: password
        )
    }
}
