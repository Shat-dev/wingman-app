//
//  OptionButton.swift
//  Wingman
//
//  Created by Adnan Khan on 30/11/2025.
//

import SwiftUI

struct OptionButton: View {
    var text: String
    var isSelected: Bool
    
    var body: some View {
        Text(text)
            .font(.manropeSemiBold(size: 16)) // Ensure font size allows for wrapping
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true) // <--- THIS IS KEY
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.wingmanBlack : Color.white)
            .foregroundColor(isSelected ? .white : .wingmanBlack)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.wingmanBlack, lineWidth: 1)
            )
            .cornerRadius(5)
            .shadow(color: Color.wingmanBlack.opacity(0.06), radius: 5, x: 0, y: 2)
    }
}
