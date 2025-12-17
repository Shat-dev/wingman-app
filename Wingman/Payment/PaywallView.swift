//
//  PaywallView.swift
//  Wingman
//
//  Created by Adnan Khan on 17/12/2025.
//


import SwiftUI

struct PaywallView: View {

    @State private var selectedPlan: Plan = .yearly
    @State private var currentPage: Int = 1

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Illustration
            Image("paywall_illustration")
                .resizable()
                .scaledToFit()
                .frame(height: 240)
                .padding(.top, 24)

            // MARK: - Feature List
            VStack(alignment: .leading, spacing: 14) {
                featureRow("Stop overthinking your next move")
                featureRow("Build confidence through short daily reps")
                featureRow("Feel more natural every time you approach")
            }
            .padding(.top, 16)
            .padding(.horizontal, 32)

            // MARK: - Page Indicator
            HStack(spacing: 6) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(index == currentPage ? Color.black : Color.black.opacity(0.25))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.top, 18)

            Spacer(minLength: 24)

            // MARK: - Plans
            VStack(spacing: 12) {

                PlanCard(
                    title: "Yearly Plan",
                    subtitle: "$79.99 per year",
                    priceNote: "only $0.96 per week",
                    isSelected: selectedPlan == .yearly,
                    badgeText: "Save 69%"
                ) {
                    selectedPlan = .yearly
                }

                PlanCard(
                    title: "Monthly Plan",
                    subtitle: "$14.99",
                    priceNote: "only $2.29 per week",
                    isSelected: selectedPlan == .monthly
                ) {
                    selectedPlan = .monthly
                }
            }
            .padding(.horizontal, 24)

            // MARK: - Continue Button
            Button(action: {
                // Handle purchase
            }) {
                Text("Continue")
                    .font(.custom("Manrope-SemiBold", size: 16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Color.black)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .background(Color.white)
    }

    // MARK: - Feature Row
    private func featureRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black)
                .padding(.top, 3)

            Text(text)
                .font(.custom("Manrope-Regular", size: 15))
                .foregroundColor(.black)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Plan Enum
enum Plan {
    case yearly
    case monthly
}

#Preview {
    PaywallView()
}
