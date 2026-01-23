// PracticeGame.swift
// Created to match provided screenshot (renamed from LessonScreen)

import SwiftUI

struct PracticeGame: View {
    // progress: 0..1, default small like the screenshot
    var progress: CGFloat = 0.12

    // optional actions
    var backAction: (() -> Void)?
    var forwardAction: (() -> Void)?

    // allow dismiss by default if no backAction supplied
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Top nav row with back chevron
            HStack {
                Button(action: {
                    if let back = backAction { back() } else { dismiss() }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(Color(hex: "#1A1A1A"))
                        .frame(width: 44, height: 44, alignment: .leading)
                }
                Spacer()
                // placeholder to keep chevron visually aligned
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Small progress capsule below nav
            TopProgressBar(progress: progress)
                .frame(height: 12)
                .padding(.horizontal, 28)
                .padding(.top, 8)
                .padding(.bottom, 18)

            // Main center content with vertical line and labels
            GeometryReader { geo in
                ZStack {
                    // Center vertical line
                    Rectangle()
                        .fill(Color(hex: "#DADADA"))
                        .frame(width: 1, height: geo.size.height * 0.6)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)

                    // Left: Back label/button
                    Button(action: {
                        if let back = backAction { back() } else { /* noop */ }
                    }) {
                        Text("Back")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Color(hex: "#8E8E93"))
                    }
                    .position(x: geo.size.width * 0.25, y: geo.size.height / 2)

                    // Right: Forward label/button
                    Button(action: {
                        if let forward = forwardAction { forward() } else { /* noop */ }
                    }) {
                        Text("Forward")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(Color(hex: "#8E8E93"))
                    }
                    .position(x: geo.size.width * 0.75, y: geo.size.height / 2)
                }
            }
            .padding(.vertical, 16)

            Spacer()

            // Bottom home indicator / hint
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "#1A1A1A"))
                .frame(width: 80, height: 4)
                .opacity(0.95)
                .padding(.bottom, 12)
        }
        .navigationBarHidden(true)
        .background(Color.white.ignoresSafeArea())
    }
}

// MARK: - TopProgressBar
private struct TopProgressBar: View {
    var progress: CGFloat = 0.12 // 0..1

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(hex: "#F0F0F0"))
                    .frame(height: 6)

                Capsule()
                    .fill(Color(hex: "#1A1A1A"))
                    // ensure a minimum visible width like your screenshot
                    .frame(width: max(28, g.size.width * progress), height: 6)
                    .animation(.easeInOut(duration: 0.25), value: progress)
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Preview
struct PracticeGame_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            NavigationStack {
                PracticeGame(progress: 0.12)
            }
            .previewDisplayName("PracticeGame")

            NavigationStack {
                PracticeGame(progress: 0.5)
            }
            .previewDisplayName("50% Progress")
        }
    }
}
