//
//  ApproachLevelGuideSheet.swift
//  Wingman
//
//  Created by Adnan Khan on 07/01/2026.
//

import SwiftUI

struct ApproachLevelGuideSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Handle bar
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                // Header
                HStack {
                    Text("Approach Level Guide")
                        .font(.manropeMedium(size: 20))
                        .foregroundColor(.wingmanBlack)

                    Spacer()

                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            dismiss()
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(ScalePressStyle())
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                Divider()
                    .background(Color.gray.opacity(0.2))

                // Content
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        // Level 1
                        LevelSection(
                            number: 1,
                            title: String(localized: "Social Practice"),
                            description: String(localized: "Developing comfort by engaging in everyday exchanges without minimal stakes."),
                            examples: [
                                String(localized: "Ask employee for recommendation"),
                                String(localized: "Greet neighbors with small talk"),
                                String(localized: "Making a light comment in a waiting line")
                            ]
                        )

                        Divider()
                            .background(Color.gray.opacity(0.2))
                            .padding(.horizontal, -20)

                        // Level 2
                        LevelSection(
                            number: 2,
                            title: String(localized: "Extended Conversation"),
                            description: String(localized: "Keeping a conversation going past small talk without any romantic incentive."),
                            examples: [
                                String(localized: "Chat with gym regular about workout routines"),
                                String(localized: "Talk to dog owner about their dog"),
                                String(localized: "Casual chat talk with fellow passenger on train")
                            ]
                        )
                        
                        Divider()
                            .background(Color.gray.opacity(0.2))
                            .padding(.horizontal, -20)

                        // Level 3
                        LevelSection(
                            number: 3,
                            title: String(localized: "Indirect Approach"),
                            description: String(localized: "Creating openings for connection while keeping it casual."),
                            examples: [
                                String(localized: "Talking to someone you may be interested in"),
                                String(localized: "Asking the person for something"),
                                String(localized: "Subtle compliment/ Playful banter")
                            ]
                        )

                        Divider()
                            .background(Color.gray.opacity(0.2))
                            .padding(.horizontal, -20)

                        // Level 4
                        LevelSection(
                            number: 4,
                            title: String(localized: "Direct Approach"),
                            description: String(localized: "Making your attraction clear right away in the opener. No ambiguity."),
                            examples: [
                                String(localized: "Approach someone you are interested straight away"),
                                String(localized: "Direct compliment on personality or appearance"),
                                String(localized: "Asking for her number (If no time to build rapport)")
                            ]
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }
            .offset(y: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                dismiss()
                            }
                        } else {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
        }
        .transition(.move(edge: .bottom))
    }
}

struct LevelSection: View {
    let number: Int
    let title: String
    let description: String
    let examples: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Level \(number): \(title)")
                .font(.manropeMedium(size: 16))
                .foregroundColor(.wingmanBlack)

            Text(description)
                .font(.manropeRegular(size: 14))
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Examples")
                    .font(.manropeMedium(size: 14))
                    .foregroundColor(.wingmanBlack)
                    .padding(.top, 4)

                ForEach(examples, id: \.self) { example in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .font(.manropeRegular(size: 14))
                            .foregroundColor(.gray)

                        Text(example)
                            .font(.manropeRegular(size: 14))
                            .foregroundColor(.gray)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }
}

// Usage example - Call this from your parent view
struct ApproachLevelGuideSheet_Preview: View {
    @State private var showGuide = false

    var body: some View {
        ZStack {
            VStack {
                Button("Show Approach Guide") {
                    showGuide = true
                }
            }
        }
        .sheet(isPresented: $showGuide) {
            ApproachLevelGuideSheet()
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(20)
        }
    }
}

#Preview {
    ApproachLevelGuideSheet_Preview()
}
