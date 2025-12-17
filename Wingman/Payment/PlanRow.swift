//
//  PlanRow.swift
//  Wingman
//
//  Created by Adnan Khan on 18/12/2025.
//

import SwiftUI

import SwiftUI

struct PlanRow: View {

    let title: String
    let price: String
    let weekly: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 12) {

                // ✅ RADIO BUTTON (same position as old checkbox)
                

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .fontWeight(.semibold)

                    Text(price)
                        .font(.caption)
                        .foregroundColor(.gray)
                }

                Spacer()

                Text(weekly)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 20))
                    .foregroundColor(.black)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isSelected ? Color.black : Color.gray.opacity(0.3),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
#Preview {
    PlanRow(title: "Basic", price: "$19.99", weekly: "£14.99/week", isSelected: false, onSelect: {})
}
