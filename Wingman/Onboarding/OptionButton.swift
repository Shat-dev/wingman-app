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
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? Color.black : Color.white)
            .foregroundColor(isSelected ? .white : .black)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.black, lineWidth: 1)
            )
            .cornerRadius(5)
            .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 2)
    }
}
