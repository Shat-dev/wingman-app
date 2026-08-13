//
//  PracticeCardView.swift
//  Wingman
//

import SwiftUI

struct PracticeCardView: View {

    // MARK: - Properties
    let practice: Practice

    /// Whether to render the completed treatment. Resolved by the parent rather
    /// than read off `practice.isCompleted` here, because the flag on its own
    /// is not evidence — it is false both for "not finished" and for "the
    /// progress read failed". `PracticeViewModel.showsCompletion(for:)` owns
    /// that distinction; this view just draws what it is told.
    let showsCompletion: Bool

    let onTap: () -> Void

    // MARK: - Derived copy
    private var lessonCountLabel: String {
        let n = practice.requiredLessonsCompleted
        let noun = n == 1 ? "lesson" : "lessons"
        let suffix = practice.isLocked ? " required" : ""
        return "\(n) \(noun)\(suffix)"
    }

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

                    // Lessons-required threshold
                    HStack(spacing: 4) {
                        Image("map")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 12, height: 12)
                            .foregroundColor(Color.wingmanBlack.opacity(practice.isLocked ? 0.3 : 1.0))

                        Text(lessonCountLabel)
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
                    .stroke(
                        // Matches the completed lesson card in CourseDetailSheet
                        // — same radius, same 1px width, same black. The
                        // unfinished colour is left exactly as it was.
                        showsCompletion ? Color.wingmanBlack : Color(hex: "#E5E5E5"),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.wingmanBlack.opacity(0.06), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(ScalePressStyle())
        .disabled(practice.isLocked)
        .padding(.bottom, 10)
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 12) {
        PracticeCardView(practice: Practice.mockData[0], showsCompletion: true, onTap: {})
        PracticeCardView(practice: Practice.mockData[2], showsCompletion: false, onTap: {})
    }
    .padding(20)
    .background(Color.white)
}
