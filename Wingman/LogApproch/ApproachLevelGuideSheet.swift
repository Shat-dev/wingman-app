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
                    Button(action: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            dismiss()
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.black)
                    }

                    

                    Text("Approach level Guide")
                        .font(.manropeMedium(size: 20))
                        .padding(.leading, 5)
                        .foregroundColor(.black)

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
                            title: "Social Practice",
                            description: "Developing comfort by engaging in everyday exchanges without minimal stakes.",
                            examples: [
                                "Ask employee for recommendation",
                                "Greet neighbors with small talk",
                                "Making a light comment in a waiting line"
                            ]
                        )

                        Divider()
                            .background(Color.gray.opacity(0.2))
                            .padding(.horizontal, -20)

                        // Level 2
                        LevelSection(
                            number: 2,
                            title: "Extended Conversation",
                            description: "Keeping a conversation going past small talk without any romantic incentive.",
                            examples: [
                                "Chat with gym regular about workout routines",
                                "Talk to dog owner about their dog",
                                "Casual chat talk with fellow passenger on train"
                            ]
                        )
                        
                        Divider()
                            .background(Color.gray.opacity(0.2))
                            .padding(.horizontal, -20)

                        // Level 3
                        LevelSection(
                            number: 3,
                            title: "Indirect Approach",
                            description: "Creating openings for connection while keeping it casual.",
                            examples: [
                                "Talking to someone you may be interested in",
                                "Asking the person for something",
                                "Subtle compliment/ Playful banter"
                            ]
                        )

                        Divider()
                            .background(Color.gray.opacity(0.2))
                            .padding(.horizontal, -20)

                        // Level 4
                        LevelSection(
                            number: 4,
                            title: "Direct Approach",
                            description: "Making your attraction clear right away in the opener. No ambiguity.",
                            examples: [
                                "Approach someone you are interested straight away",
                                "Direct compliment on personality or appearance",
                                "Asking for her number (If no time to build rapport)"
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
                .foregroundColor(.black)

            Text(description)
                .font(.manropeRegular(size: 14))
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                Text("Examples")
                    .font(.manropeMedium(size: 14))
                    .foregroundColor(.black)
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
