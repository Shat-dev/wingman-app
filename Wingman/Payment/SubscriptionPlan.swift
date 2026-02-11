//
//  SubscriptionPlan.swift
//  Wingman
//
//  Created by Adnan Khan on 18/12/2025.
//

import SwiftUI

enum SubscriptionPlan: String {
    case yearly
    case monthly
}

struct PaywallPage: Identifiable {
    let id = UUID()
    let imageName: String
    let bullets: [String]
}
