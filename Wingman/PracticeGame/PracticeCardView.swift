//
//  PracticeCardView.swift
//  Wingman
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
                        .font(.manropeMedium(size: 18))
                        .foregroundColor(Color.wingmanBlack.opacity(practice.isLocked ? 0.3 : 1.0))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Daily Practice Count
                    HStack(spacing: 4) {
                        Image("flame_fill")
                            .resizable()
                            .scaledToFit()
                            .opacity(practice.isLocked ? 0.3 : 1.0)
                            .frame(width: 8, height: 12)

                        Text("\(practice.dailyPracticeCount) Daily Practice")
                            .font(.manropeMedium(size: 12))
                            .foregroundColor(Color.wingmanBlack.opacity(practice.isLocked ? 0.3 : 1.0))
                    }

                    // Summary
                    Text(practice.summary)
                        .font(.manropeMedium(size: 14))
                        .foregroundColor(Color.wingmanBlack.opacity(practice.isLocked ? 0.3 : 1.0))
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right Content - Image & Lock
                ZStack(alignment: .topTrailing) {
                    // Practice Image
                    Image(practice.imageUrl.isEmpty ? "c_girl" : practice.imageUrl)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 70, height: 110)
                        .opacity(practice.isLocked ? 0.4 : 1.0)

                    // Lock Icon (if locked)
                    if practice.isLocked {
                        Image("lock_icon")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Color.wingmanBlack)
                            .offset(x: 10, y: -10)
                            .opacity(0.7)
                    }
                }
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(hex: "#E5E5E5"), lineWidth: 1)
            )
            .shadow(color: Color.wingmanBlack.opacity(0.06), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(PracticeCardButtonStyle())
        .disabled(practice.isLocked)
        .padding(.bottom, 10)
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
        PracticeCardView(practice: Practice.mockData[0], onTap: {})
        PracticeCardView(practice: Practice.mockData[2], onTap: {})
    }
    .padding(20)
    .background(Color.white)
}
