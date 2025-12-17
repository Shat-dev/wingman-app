//
//  PaywallViewModel.swift
//  Wingman
//
//  Created by Adnan Khan on 18/12/2025.
//


import Foundation
import Combine

import Foundation
import SwiftUI

final class PaywallViewModel: ObservableObject {

    // MARK: - Carousel
    @Published var currentPage: Int = 0

    let pages: [PaywallPage] = [
        PaywallPage(
            imageName: "paywall_1",
            bullets: [
                "Stop guessing what to say next",
                "Practice real encounters through scenario-based games",
                "Be ready for any situation before it happens"
            ]
        ),
        PaywallPage(
            imageName: "paywall_2",
            bullets: [
                "See your confidence grow with real data",
                "Track your approaches, reflections, and progress",
                "Stay motivated as you watch yourself improve"
            ]
        )
    ]

    // MARK: - Plan
    @Published var selectedPlan: SubscriptionPlan = .yearly

    func selectPlan(_ plan: SubscriptionPlan) {
        selectedPlan = plan
        print("🧾 Selected plan:", plan.rawValue)
    }

    func continueTapped() {
        print("➡️ Continue with plan:", selectedPlan.rawValue)
    }
}

