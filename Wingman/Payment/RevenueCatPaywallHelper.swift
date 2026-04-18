//
//  RevenueCatPaywallHelper.swift
//  Wingman
//
//  Created by Adnan Khan on 06/04/2026.
//

import SwiftUI
import RevenueCat
import RevenueCatUI
import Combine

/// Helper class to manage RevenueCat paywall presentation
@MainActor
final class RevenueCatPaywallHelper: ObservableObject {
    @Published var isPaywallPresented = false
    
    /// Check if user needs to see paywall and present it if necessary
    func checkAndPresentPaywallIfNeeded() async -> Bool {
        do {
            let customerInfo = try await Purchases.shared.customerInfo()
            let hasEntitlement = customerInfo.entitlements[Constants.ENTITLEMENT_ID]?.isActive == true
            
            // Also check if anonymous user has active purchase that might not be linked yet
            let anonymousManager = AnonymousUserManager.shared
            let hasAnonymousPurchase = anonymousManager.hasActivePurchase
            
            // User doesn't need paywall if they have entitlement OR anonymous purchase
            let needsPaywall = !hasEntitlement && !hasAnonymousPurchase
            
            if needsPaywall {
                log("💰 RevenueCatPaywallHelper: User needs paywall - showing...")
                isPaywallPresented = true
                return true
            } else {
                if hasEntitlement {
                    log("✅ RevenueCatPaywallHelper: User has active entitlement - no paywall needed")
                } else if hasAnonymousPurchase {
                    log("💰 RevenueCatPaywallHelper: Anonymous user has purchase - no paywall needed")
                }
                return false
            }
        } catch {
            log("❌ RevenueCatPaywallHelper: Error checking customer info: \(error)")
            // On error, check if anonymous user has purchase before showing paywall
            let anonymousManager = AnonymousUserManager.shared
            if anonymousManager.hasActivePurchase {
                log("💰 RevenueCatPaywallHelper: Anonymous purchase found despite error - no paywall")
                return false
            }
            // If no anonymous purchase and error occurred, show paywall to be safe
            isPaywallPresented = true
            return true
        }
    }
    
    /// Manually present paywall
    func presentPaywall() {
        isPaywallPresented = true
    }
    
    /// Handle successful purchase
    func handlePurchaseCompleted(_ customerInfo: CustomerInfo) {
        log("✅ RevenueCatPaywallHelper: Purchase completed")
        isPaywallPresented = false
        
        // Update RevenueCat manager
        Task {
            await RevenueCatManager.shared.refreshCustomerInfo()
        }
    }
    
    /// Handle successful restore
    func handleRestoreCompleted(_ customerInfo: CustomerInfo) {
        log("🔄 RevenueCatPaywallHelper: Restore completed")
        
        // Check if entitlement is now active
        let hasEntitlement = customerInfo.entitlements[Constants.ENTITLEMENT_ID]?.isActive == true
        if hasEntitlement {
            isPaywallPresented = false
        }
        
        // Update RevenueCat manager
        Task {
            await RevenueCatManager.shared.refreshCustomerInfo()
        }
    }
}

/// SwiftUI View modifier for manual paywall presentation
struct PaywallPresentation: ViewModifier {
    @StateObject private var helper = RevenueCatPaywallHelper()
    let shouldCheckOnAppear: Bool
    
    init(shouldCheckOnAppear: Bool = true) {
        self.shouldCheckOnAppear = shouldCheckOnAppear
    }
    
    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $helper.isPaywallPresented) {
                PaywallView()
                    .onPurchaseCompleted { customerInfo in
                        helper.handlePurchaseCompleted(customerInfo)
                    }
                    .onRestoreCompleted { customerInfo in
                        helper.handleRestoreCompleted(customerInfo)
                    }
            }
            .onAppear {
                if shouldCheckOnAppear {
                    Task {
                        await helper.checkAndPresentPaywallIfNeeded()
                    }
                }
            }
            .environmentObject(helper)
    }
}

/// Convenience extension for easy usage
extension View {
    /// Presents RevenueCat paywall manually when needed
    func presentRevenueCatPaywall(shouldCheckOnAppear: Bool = true) -> some View {
        modifier(PaywallPresentation(shouldCheckOnAppear: shouldCheckOnAppear))
    }
}
