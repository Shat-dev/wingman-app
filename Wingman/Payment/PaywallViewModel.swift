//
//  PaywallViewModel.swift
//  Wingman
//
//  Created by Adnan Khan on 18/12/2025.
//

import Foundation
import SwiftUI
import Combine

final class PaywallViewModel: ObservableObject {

    // MARK: - Carousel
    @Published var currentPage: Int = 0

    let pages: [PaywallPage] = [
        PaywallPage(
            imageName: "paywall_1",
            bullets: [
                "Stop overthinking your next move",
                "Feel more natural each time you talk",
                "Learn core social and flirting skills through daily reps"
            ]
        ),
        PaywallPage(
            imageName: "paywall_2",
            bullets: [
                "Develop the skills most men were never taught",
                "Master mindset, communication, flirting, and approach mechanics step-by-step",
                "Learn how to create attraction & interest"
            ]
        ),
        PaywallPage(
            imageName: "paywall_3",
            bullets: [
                "Stop guessing what to say next",
                "Practice real encounters through scenario-based games",
                "Be ready for any situation before it happens"
            ]
        ),
        PaywallPage(
            imageName: "paywall_4",
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
    
    // MARK: - Footer Links
    func openPrivacy() {
        if let url = URL(string: "https://example.com/privacy") {
            UIApplication.shared.open(url)
        }
    }
    
    func openRestore() {
        print("🔄 Restore purchases tapped")
        // Add restore purchases logic here
    }
    
    func openTerms() {
        if let url = URL(string: "https://example.com/terms") {
            UIApplication.shared.open(url)
        }
    }
}
