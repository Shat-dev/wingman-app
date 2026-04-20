//
//  RevenueCatManager.swift
//  Wingman
//
//  Created by Adnan Khan on 06/04/2026.
//

import Foundation
import RevenueCat
import SwiftUI
import Combine

@MainActor
final class RevenueCatManager: NSObject, ObservableObject {
    static let shared = RevenueCatManager()
    
    // MARK: - Published Properties
    @Published var customerInfo: CustomerInfo?
    @Published var offerings: Offerings?
    @Published var isLoading = false
    @Published var error: RevenueCatError?
    
    // MARK: - Constants
    private let apiKey = Constants.REVENUE_CAT_API_KEY
    private let entitlementID = Constants.ENTITLEMENT_ID
    
    // MARK: - Computed Properties
    var isSubscribed: Bool {
        customerInfo?.entitlements[entitlementID]?.isActive == true
    }
    
    var activeSubscription: String? {
        guard let customerInfo = customerInfo else { return nil }
        return customerInfo.entitlements[entitlementID]?.productIdentifier
    }
    
    private override init() {
        super.init()
        configure()
    }
    
    // MARK: - Configuration
    func configure() {
        // Skip RevenueCat configuration if using StoreKit testing mode
        if RevenueCatConfig.useStoreKitTestingMode {
            log("🧪 RevenueCat: SKIPPED - Using StoreKit Testing Mode")
            return
        }
        
        log("🔧 RevenueCat: Configuring with API Key")
        // Verbose RevenueCat logs in Debug only — Release ships with .error
        // so production console noise is limited to real failures.
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .error
        #endif
        Purchases.configure(withAPIKey: apiKey)
        Purchases.shared.delegate = self
        
        Task {
            await refreshCustomerInfo()
            await fetchOfferings()
        }
    }
    
    // MARK: - User Management
    func setUserID(_ userID: String) {
        Task {
            do {
                _ = try await Purchases.shared.logIn(userID)
                await refreshCustomerInfo()
                log("🔑 RevenueCat: User logged in with ID: \(userID)")
            } catch {
                log("❌ RevenueCat: Failed to login user: \(error)")
            }
        }
    }
    
    func logoutUser() {
        Task {
            do {
                _ = try await Purchases.shared.logOut()
                await refreshCustomerInfo()
                log("👋 RevenueCat: User logged out")
            } catch {
                log("❌ RevenueCat: Failed to logout user: \(error)")
            }
        }
    }
    
    /// Link anonymous user purchases to authenticated account
    func linkAnonymousUserPurchases(_ userID: String) async -> Bool {
        let anonymousManager = AnonymousUserManager.shared
        
        guard anonymousManager.needsRevenueCatLinking else {
            log("ℹ️ RevenueCat: No anonymous purchases to link")
            return true
        }
        
        guard let anonymousCustomerID = anonymousManager.revenueCatCustomerId else {
            log("❌ RevenueCat: No anonymous customer ID found")
            return false
        }
        
        log("🔗 RevenueCat: Linking anonymous purchases to authenticated user")
        log("   - Anonymous Customer ID: \(anonymousCustomerID)")
        log("   - Authenticated User ID: \(userID)")
        
        do {
            // First, switch to the anonymous customer to get their purchases
            _ = try await Purchases.shared.logIn(anonymousCustomerID)
            let anonymousCustomerInfo = try await Purchases.shared.customerInfo()
            
            log("📋 RevenueCat: Anonymous customer info retrieved")
            log("   - Active entitlements: \(anonymousCustomerInfo.entitlements.active.keys)")
            
            // Now login with the authenticated user ID to transfer purchases
            _ = try await Purchases.shared.logIn(userID)
            let finalCustomerInfo = try await Purchases.shared.customerInfo()
            
            log("✅ RevenueCat: Successfully linked to authenticated user")
            log("   - Final entitlements: \(finalCustomerInfo.entitlements.active.keys)")
            
            // Verify the purchase was transferred
            let hasEntitlement = finalCustomerInfo.entitlements[entitlementID]?.isActive == true
            if hasEntitlement {
                log("✅ RevenueCat: Purchase successfully transferred!")
                
                // Clear anonymous purchase data since it's now linked
                anonymousManager.revenueCatCustomerId = nil
                anonymousManager.hasActivePurchase = false
                
                // Update local customer info
                await MainActor.run {
                    self.customerInfo = finalCustomerInfo
                }
                
                return true
            } else {
                log("⚠️ RevenueCat: Purchase transfer may not be complete")
                return false
            }
            
        } catch {
            log("❌ RevenueCat: Failed to link anonymous purchases: \(error)")
            return false
        }
    }
    
    // MARK: - Customer Info
    func refreshCustomerInfo() async {
        do {
            isLoading = true
            let info = try await Purchases.shared.customerInfo()
            customerInfo = info
            error = nil

            log("ℹ️ RevenueCat: Customer info refreshed")
        } catch {
            self.error = RevenueCatError.customerInfoFailed(error.localizedDescription)
            log("❌ RevenueCat: Failed to get customer info: \(error)")
        }
        isLoading = false
    }
    
    // MARK: - Offerings
    func fetchOfferings() async {
        do {
            isLoading = true
            let fetchedOfferings = try await Purchases.shared.offerings()
            offerings = fetchedOfferings
            error = nil
            log("📦 RevenueCat: Offerings fetched: \(fetchedOfferings.all.count) offerings")
        } catch {
            self.error = RevenueCatError.offeringsFailed(error.localizedDescription)
            log("❌ RevenueCat: Failed to fetch offerings: \(error)")
        }
        isLoading = false
    }
    
    // MARK: - Purchases
    func purchase(_ package: Package) async -> Bool {
        do {
            isLoading = true
            let (_, customerInfo, _) = try await Purchases.shared.purchase(package: package)
            self.customerInfo = customerInfo
            error = nil
            
            let success = customerInfo.entitlements[entitlementID]?.isActive == true
            log("💰 RevenueCat: Purchase completed. Entitled: \(success)")
            isLoading = false
            return success
        } catch {
            self.error = RevenueCatError.purchaseFailed(error.localizedDescription)
            log("❌ RevenueCat: Purchase failed: \(error)")
            isLoading = false
            return false
        }
    }
    
    func restorePurchases() async -> Bool {
        do {
            isLoading = true
            let customerInfo = try await Purchases.shared.restorePurchases()
            self.customerInfo = customerInfo
            error = nil
            
            let success = customerInfo.entitlements[entitlementID]?.isActive == true
            log("🔄 RevenueCat: Restore completed. Entitled: \(success)")
            isLoading = false
            return success
        } catch {
            self.error = RevenueCatError.restoreFailed(error.localizedDescription)
            log("❌ RevenueCat: Restore failed: \(error)")
            isLoading = false
            return false
        }
    }
    
    // MARK: - Subscription Status
    func checkSubscriptionStatus() -> SubscriptionStatus {
        guard let customerInfo = customerInfo else {
            return .unknown
        }
        
        guard let entitlement = customerInfo.entitlements[entitlementID] else {
            return .notSubscribed
        }
        
        if entitlement.isActive {
            return .subscribed(productID: entitlement.productIdentifier)
        } else {
            return .expired
        }
    }
    
    // MARK: - Product Information
    func getYearlyPackage() -> Package? {
        return offerings?.current?.package(identifier: "yearly") ??
               offerings?.current?.annual
    }
    
    func getMonthlyPackage() -> Package? {
        return offerings?.current?.package(identifier: "monthly") ??
               offerings?.current?.monthly
    }
    
    func getAllPackages() -> [Package] {
        return offerings?.current?.availablePackages ?? []
    }
}

// MARK: - PurchasesDelegate
extension RevenueCatManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        Task { @MainActor in
            self.customerInfo = customerInfo
            log("🔄 RevenueCat: Customer info updated via delegate")
        }
    }
}

// MARK: - Supporting Types
enum RevenueCatError: LocalizedError {
    case customerInfoFailed(String)
    case offeringsFailed(String)
    case purchaseFailed(String)
    case restoreFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .customerInfoFailed(let message):
            return "Failed to get customer info: \(message)"
        case .offeringsFailed(let message):
            return "Failed to fetch products: \(message)"
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        case .restoreFailed(let message):
            return "Restore failed: \(message)"
        }
    }
}

enum SubscriptionStatus {
    case unknown
    case notSubscribed
    case subscribed(productID: String)
    case expired
    
    var isActive: Bool {
        if case .subscribed = self {
            return true
        }
        return false
    }
}
