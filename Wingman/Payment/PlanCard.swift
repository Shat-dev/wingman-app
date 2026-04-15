//
//  PlanCard.swift
//  Wingman
//
//  Created by Adnan Khan on 17/12/2025.
//

import SwiftUI

struct PlanCard: View {

    let title: String
    let subtitle: String
    let priceNote: String
    let isSelected: Bool
    var badgeText: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {

                if let badgeText {
                    HStack {
                        Text(badgeText)
                            .font(.custom("Manrope-SemiBold", size: 12))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.wingmanBlack)
                            .cornerRadius(6)

                        Spacer()
                    }
                    .padding(.bottom, 6)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.custom("Manrope-SemiBold", size: 16))
                            .foregroundColor(.wingmanBlack)

                        Text(subtitle)
                            .font(.custom("Manrope-Regular", size: 13))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(priceNote)
                            .font(.custom("Manrope-Regular", size: 13))
                            .foregroundColor(.gray)

                        Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 22))
                            .foregroundColor(.wingmanBlack)
                    }
                }
                .padding()
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.wingmanBlack : Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
