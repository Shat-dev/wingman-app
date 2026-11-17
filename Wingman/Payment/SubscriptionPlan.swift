//
//  SubscriptionPlan.swift
//  Wingman
//
//  Created by Adnan Khan on 18/12/2025.
//

import SwiftUI
import RevenueCat

enum SubscriptionPlan: String {
    case yearly
    case monthly
    /// A one-time purchase that never expires. Offered only when the
    /// RevenueCat offering carries a lifetime package.
    case lifetime
}

extension Offering {

    /// The package behind each plan, by the identifier it has in the
    /// RevenueCat dashboard or, failing that, by its package type.
    func package(for plan: SubscriptionPlan) -> Package? {
        switch plan {
        case .yearly:   return package(identifier: "yearly") ?? annual
        case .monthly:  return package(identifier: "monthly") ?? monthly
        case .lifetime: return package(identifier: "lifetime") ?? lifetime
        }
    }
}

struct PaywallPage: Identifiable {
    let id = UUID()
    let imageName: String
    var headline: String? = nil
    let bullets: [String]
}
