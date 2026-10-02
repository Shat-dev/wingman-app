//
//  TrialTimeline.swift
//  Wingman
//
//  Three-step strip under the plan cards: what happens today, that the user
//  can leave at any point, and the day and amount of the first charge.
//
//  Deliberately has no "we'll remind you" step. That is the usual middle step
//  in this pattern, but Wingman sends no trial-end reminder, and promising one
//  would be a false claim on a payment screen. Add the step only alongside
//  the notification that makes it true.
//

import SwiftUI

struct TrialTimeline: View {

    let zeroPrice: String
    let trialDays: Int
    let priceWithPeriod: String

    private let secondary = Color(hex: "6B7280")

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            step(title: "Today", detail: "Full access for \(zeroPrice)", filled: true)
            step(title: "Anytime", detail: "Cancel, no charge", filled: false)
            step(title: "Day \(trialDays)", detail: "\(priceWithPeriod) begins", filled: false)
        }
        // One line connecting the three dots, drawn behind them.
        .background(alignment: .top) {
            GeometryReader { geo in
                Rectangle()
                    .fill(Color(hex: "D1D5DB"))
                    .frame(width: geo.size.width * 2 / 3, height: 1.5)
                    .offset(x: geo.size.width / 6, y: 5.25)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func step(title: String, detail: String, filled: Bool) -> some View {
        VStack(spacing: 6) {
            Circle()
                .fill(filled ? Color.wingmanBlack : Color.white)
                .overlay(Circle().stroke(Color.wingmanBlack, lineWidth: 1.5))
                .frame(width: 12, height: 12)
            Text(title)
                .font(.manropeSemiBold(size: 13))
                .foregroundColor(.wingmanBlack)
            Text(detail)
                .font(.manropeMedium(size: 11))
                .foregroundColor(secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }
}
