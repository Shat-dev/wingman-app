//
//  AccountDeletionModels.swift
//  Wingman
//
//  Created by System on 12/03/2026.
//

import Foundation

// MARK: - Account Deletion Models
struct AccountDeletionResponse: Codable {
    let success: Bool
    let message: String
    let deletedUserId: String?
    let error: String?
}

enum AccountDeletionError: LocalizedError {
    case notAuthenticated
    case invalidSession
    case networkError(String)
    case deletionFailed(String)
    case invalidResponse
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .invalidSession:
            return "Invalid session"
        case .networkError(let message):
            return "Network error: \(message)"
        case .deletionFailed(let message):
            return "Account deletion failed: \(message)"
        case .invalidResponse:
            return "Invalid response from server"
        }
    }
}