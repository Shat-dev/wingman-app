//
//  PracticeCardView.swift
//  Wingman
//
//  Created by Adnan Khan on 23/01/2026.
//

import SwiftUI

struct PracticeCardView: View {
    
    // MARK: - Properties
    let practice: Practice
    let onTap: () -> Void
    
    // MARK: - Body
    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Left Content
                VStack(alignment: .leading, spacing: 6) {
                    // Title
                    Text(practice.title)
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(practice.isLocked ? Color(hex: "#999999") : Color(hex: "#1A1A1A"))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Daily Practice Count
                    HStack(spacing: 4) {
                        Text("🔥")
                            .font(.system(size: 12))
                        
                        Text("\(practice.dailyPracticeCount) Daily Practice")
                            .font(.manropeMedium(size: 12))
                            .foregroundColor(practice.isLocked ? Color(hex: "#BBBBBB") : Color(hex: "#666666"))
                    }
                    
                    // Summary
                    Text(practice.summary)
                        .font(.manropeRegular(size: 13))
                        .foregroundColor(practice.isLocked ? Color(hex: "#AAAAAA") : Color(hex: "#666666"))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Right Content - Image & Lock
                ZStack(alignment: .topTrailing) {
                    // Practice Image
                    Image(practice.imageUrl)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 80, height: 80)
                        .opacity(practice.isLocked ? 0.4 : 1.0)
                    
                    // Lock Icon (if locked)
                    if practice.isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color(hex: "#999999"))
                            .offset(x: 4, y: -4)
                    }
                }
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(hex: "#E5E5E5"), lineWidth: 1)
            )
        }
        .buttonStyle(PracticeCardButtonStyle())
        .disabled(practice.isLocked)
    }
}

// MARK: - Custom Button Style
struct PracticeCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: configuration.isPressed)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 12) {
        PracticeCardView(
            practice: Practice.mockData[0],
            onTap: {}
        )
        
        PracticeCardView(
            practice: Practice.mockData[2],
            onTap: {}
        )
    }
    .padding(16)
    .background(Color.white)
}
