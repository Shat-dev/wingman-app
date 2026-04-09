//
//  RevenueCatConfig.swift
//  Wingman
//
//  Created by GitHub Copilot
//  Configuration for RevenueCat API keys and environment setup
//

import Foundation

/// RevenueCat Configuration
/// This file manages API keys for both sandbox (Debug) and production (Release) builds
/// Update the API keys below with your own from the RevenueCat dashboard
struct RevenueCatConfig {
    
    // MARK: - API Keys
    /// Test API Key for Debug builds (Sandbox environment)
    /// Get this from RevenueCat Dashboard → Settings → API Keys
    /// Format: pk_test_xxxxx
    #if DEBUG
    static let apiKey = "test_XgrFFhyycXzIDPuxOTPgNDjXGhR"
    #else
    /// Production API Key for Release builds (TestFlight & App Store)
    /// Get this from RevenueCat Dashboard → Settings → API Keys
    /// Format: pk_prod_xxxxx
    static let apiKey = "appl_XpppZVRiLkEMoJBtHGtkGErPqMA"
    #endif
    
    // MARK: - Entitlements
    /// Main premium entitlement identifier
    /// This should match the entitlement configured in your RevenueCat dashboard
    static let premiumEntitlementId = "Wingman Pro"
    
    // MARK: - Product Identifiers
    /// Product IDs that match your App Store Connect configuration
    struct ProductIds {
        /// Annual subscription product ID
        static let yearly = "wingman_yearly"
        
        /// Monthly subscription product ID
        static let monthly = "wingman_monthly"
    }
    
    // MARK: - Environment Detection
    /// Indicates whether the app is running in debug mode
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
    
    /// Returns a human-readable environment name
    static var environment: String {
        isDebug ? "Sandbox (Debug)" : "Production (Release)"
    }
    
    /// Redacted API key for logging (masks sensitive data)
    static var redactedApiKey: String {
        let key = apiKey
        guard key.count > 8 else { return "***" }
        let start = key.prefix(4)
        let end = key.suffix(4)
        return "\(start)...\(end)"
    }
    
    // MARK: - Configuration Info
    /// Prints configuration info for debugging
    static func logConfiguration() {
        print("""
        ╔═══════════════════════════════════════════════════════╗
        ║          RevenueCat Configuration                     ║
        ╠═══════════════════════════════════════════════════════╣
        ║ Environment:      \(environment.padding(toLength: 30, withPad: " ", startingAt: 0))║
        ║ API Key:          \(redactedApiKey.padding(toLength: 30, withPad: " ", startingAt: 0))║
        ║ Entitlement:      \(premiumEntitlementId.padding(toLength: 30, withPad: " ", startingAt: 0))║
        ║ Yearly Product:   \(ProductIds.yearly.padding(toLength: 30, withPad: " ", startingAt: 0))║
        ║ Monthly Product:  \(ProductIds.monthly.padding(toLength: 30, withPad: " ", startingAt: 0))║
        ╚═══════════════════════════════════════════════════════╝
        """)
    }
}

// MARK: - Helper Extension for String Padding
extension String {
    fileprivate func padding(toLength length: Int, withPad padString: String, startingAt padIndex: Int) -> String {
        let currentLength = self.count
        guard currentLength < length else { return self }
        let paddingNeeded = length - currentLength
        let padding = String(repeating: padString, count: paddingNeeded)
        return self + padding
    }
}
