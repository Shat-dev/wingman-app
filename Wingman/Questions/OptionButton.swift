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
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.3), lineWidth: 1)
            )
            .cornerRadius(8)
    }
}
