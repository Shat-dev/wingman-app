//
//  PlanRow.swift
//  Wingman
//
//  Created by Adnan Khan on 18/12/2025.
//

import SwiftUI

struct PlanRow: View {

    let title: String
    let price: String
    let weekly: String
    let weeklySubtitle: String
    let isSelected: Bool
    var badgeText: String? = nil
    /// A pill ("Most Popular") straddling the card's top edge. Drawn as an
    /// overlay so it never changes the card's height; whoever places the row
    /// leaves `highlightOverhang` of room above it.
    var highlightText: String? = nil
    let onSelect: () -> Void

    /// How far the highlight pill rises above the card's top edge.
    static let highlightOverhang: CGFloat = 11

    var body: some View {
        Button {
            HapticManager.shared.selection()
            onSelect()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                
                // Badge Header (if present)
                if let badgeText = badgeText {
                    Text(badgeText)
                        .font(.manropeMedium(size: 14))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 3)
                        .background(Color.wingmanBlack)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                
                // Plan Content
                HStack(alignment: .center, spacing: 0) {
                    
                    // Left side - Title and Price
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.manropeSemiBold(size: 16))
                            .foregroundColor(.wingmanBlack)

                        Text(price)
                            .font(.manropeSemiBold(size: 12))
                            .foregroundColor(Color(hex: "6B7280"))
                    }

                    Spacer()

                    // Right side - Weekly price and Radio
                    HStack(alignment: .center, spacing: 14) {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(weekly)
                                .font(.manropeSemiBold(size: 16))
                                .foregroundColor(Color(hex: "6B7280"))

                            Text(weeklySubtitle)
                                .font(.manropeSemiBold(size: 12))
                                .foregroundColor(Color(hex: "6B7280"))
                        }
                        
                        // Radio Button
                        ZStack {
                            Circle()
                                .stroke(isSelected ? Color.wingmanBlack : Color(hex: "D1D5DB"), lineWidth: 2)
                                .frame(width: 24, height: 24)

                            Circle()
                                .fill(Color.wingmanBlack)
                                .frame(width: 12, height: 12)
                                .opacity(isSelected ? 1 : 0)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 5))
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(isSelected ? Color.wingmanBlack : Color(hex: "#E8E8E8"), lineWidth: isSelected ? 1.5 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if let highlightText {
                    Text(highlightText)
                        .font(.manropeBold(size: 11))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .padding(.horizontal, 10)
                        .frame(height: Self.highlightOverhang * 2)
                        .background(Capsule().fill(Color.wingmanBlack))
                        // A white ring keeps the pill distinct from the black
                        // trial strip when that header is showing.
                        .overlay(Capsule().stroke(Color.white, lineWidth: 2))
                        .offset(y: -Self.highlightOverhang)
                        // Lines up with the radio button's right edge.
                        .padding(.trailing, 16)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: badgeText != nil)
        }
        .buttonStyle(ScalePressStyle())
    }
}

#Preview {
    VStack(spacing: 12) {
        PlanRow(
            title: "Yearly Plan",
            price: "$44.99 per year",
            weekly: "only $0.96",
            weeklySubtitle: "per week",
            isSelected: true,
            badgeText: "3-day Free Trial",
            highlightText: "Most Popular",
            onSelect: {}
        )
        
        PlanRow(
            title: "Monthly Plan",
            price: "$12.99",
            weekly: "only $2.29",
            weeklySubtitle: "per week",
            isSelected: false,
            badgeText: nil,
            onSelect: {}
        )
    }
    .padding()
}
