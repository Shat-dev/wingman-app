//
//  SubscriptionHelper.swift
//  Wingman
//
//  Created by Adnan Khan on 06/04/2026.
//

import Foundation
import RevenueCat
import SwiftUI
import Combine

/// Helper class to check subscription status across the app
@MainActor
final class SubscriptionHelper: ObservableObject {
    static let shared = SubscriptionHelper()
    
    @Published var hasActiveSubscription = false
    @Published var subscriptionProduct: String?
    
    private init() {
        // Monitor RevenueCat manager changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(customerInfoUpdated),
            name: NSNotification.Name("RevenueCatCustomerInfoUpdated"),
            object: nil
        )
        
        checkSubscriptionStatus()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func customerInfoUpdated() {
        checkSubscriptionStatus()
    }
    
    func checkSubscriptionStatus() {
        let manager = RevenueCatManager.shared
        hasActiveSubscription = manager.isSubscribed
        subscriptionProduct = manager.activeSubscription
        
        log("🔄 SubscriptionHelper: Status updated - hasActive: \(hasActiveSubscription), product: \(subscriptionProduct ?? "none")")
    }
    
    /// Check if user has access to premium features
    var hasPremiumAccess: Bool {
        return hasActiveSubscription
    }
    
    /// Check if user has specific product access
    func hasAccess(to productId: String) -> Bool {
        return subscriptionProduct == productId
    }
}

/// View modifier to check subscription status and show paywall if needed
struct RequireSubscription: ViewModifier {
    @StateObject private var subscriptionHelper = SubscriptionHelper.shared
    @State private var showPaywall = false
    
    let feature: String
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                subscriptionHelper.checkSubscriptionStatus()
            }
            .onChange(of: subscriptionHelper.hasActiveSubscription) { hasSubscription in
                if !hasSubscription {
                    showPaywall = true
                }
            }
            .sheet(isPresented: $showPaywall) {
                NavigationView {
                    PaywallView()
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
                                Button("Close") {
                                    showPaywall = false
                                }
                            }
                        }
                }
            }
    }
}

extension View {
    /// Require active subscription to access this view
    func requireSubscription(for feature: String = "Premium Feature") -> some View {
        modifier(RequireSubscription(feature: feature))
    }
}
