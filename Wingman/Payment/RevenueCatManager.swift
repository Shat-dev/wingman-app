//
//  RevenueCatManager.swift
//  Wingman
//
//  Created by Assistant on 06/04/2026.
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
        Purchases.logLevel = .debug
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
                print("🔑 RevenueCat: User logged in with ID: \(userID)")
            } catch {
                print("❌ RevenueCat: Failed to login user: \(error)")
            }
        }
    }
    
    func logoutUser() {
        Task {
            do {
                _ = try await Purchases.shared.logOut()
                await refreshCustomerInfo()
                print("👋 RevenueCat: User logged out")
            } catch {
                print("❌ RevenueCat: Failed to logout user: \(error)")
            }
        }
    }
    
    /// Link anonymous user purchases to authenticated account
    func linkAnonymousUserPurchases(_ userID: String) async -> Bool {
        let anonymousManager = AnonymousUserManager.shared
        
        guard anonymousManager.needsRevenueCatLinking else {
            print("ℹ️ RevenueCat: No anonymous purchases to link")
            return true
        }
        
        guard let anonymousCustomerID = anonymousManager.revenueCatCustomerId else {
            print("❌ RevenueCat: No anonymous customer ID found")
            return false
        }
        
        print("🔗 RevenueCat: Linking anonymous purchases to authenticated user")
        print("   - Anonymous Customer ID: \(anonymousCustomerID)")
        print("   - Authenticated User ID: \(userID)")
        
        do {
            // First, switch to the anonymous customer to get their purchases
            _ = try await Purchases.shared.logIn(anonymousCustomerID)
            let anonymousCustomerInfo = try await Purchases.shared.customerInfo()
            
            print("📋 RevenueCat: Anonymous customer info retrieved")
            print("   - Active entitlements: \(anonymousCustomerInfo.entitlements.active.keys)")
            
            // Now login with the authenticated user ID to transfer purchases
            _ = try await Purchases.shared.logIn(userID)
            let finalCustomerInfo = try await Purchases.shared.customerInfo()
            
            print("✅ RevenueCat: Successfully linked to authenticated user")
            print("   - Final entitlements: \(finalCustomerInfo.entitlements.active.keys)")
            
            // Verify the purchase was transferred
            let hasEntitlement = finalCustomerInfo.entitlements[entitlementID]?.isActive == true
            if hasEntitlement {
                print("✅ RevenueCat: Purchase successfully transferred!")
                
                // Clear anonymous purchase data since it's now linked
                anonymousManager.revenueCatCustomerId = nil
                anonymousManager.hasActivePurchase = false
                
                // Update local customer info
                await MainActor.run {
                    self.customerInfo = finalCustomerInfo
                }
                
                return true
            } else {
                print("⚠️ RevenueCat: Purchase transfer may not be complete")
                return false
            }
            
        } catch {
            print("❌ RevenueCat: Failed to link anonymous purchases: \(error)")
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
            
            // Post notification for SubscriptionHelper
            NotificationCenter.default.post(
                name: NSNotification.Name("RevenueCatCustomerInfoUpdated"),
                object: nil
            )
            
            print("ℹ️ RevenueCat: Customer info refreshed")
        } catch {
            self.error = RevenueCatError.customerInfoFailed(error.localizedDescription)
            print("❌ RevenueCat: Failed to get customer info: \(error)")
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
            print("📦 RevenueCat: Offerings fetched: \(fetchedOfferings.all.count) offerings")
        } catch {
            self.error = RevenueCatError.offeringsFailed(error.localizedDescription)
            print("❌ RevenueCat: Failed to fetch offerings: \(error)")
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
            print("💰 RevenueCat: Purchase completed. Entitled: \(success)")
            isLoading = false
            return success
        } catch {
            self.error = RevenueCatError.purchaseFailed(error.localizedDescription)
            print("❌ RevenueCat: Purchase failed: \(error)")
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
            print("🔄 RevenueCat: Restore completed. Entitled: \(success)")
            isLoading = false
            return success
        } catch {
            self.error = RevenueCatError.restoreFailed(error.localizedDescription)
            print("❌ RevenueCat: Restore failed: \(error)")
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
            
            // Post notification for SubscriptionHelper
            NotificationCenter.default.post(
                name: NSNotification.Name("RevenueCatCustomerInfoUpdated"),
                object: nil
            )
            
            print("🔄 RevenueCat: Customer info updated via delegate")
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
