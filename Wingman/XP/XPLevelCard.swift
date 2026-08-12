//
//  XPLevelCard.swift
//  Wingman
//
//  Profile's level and XP card. Sits alongside WeekStreakCard.
//

import SwiftUI

/// Level, progress to the next one, and the running total.
///
/// Takes an optional so it can tell "not loaded yet" from "loaded, and it is
/// zero" — the distinction `XPStore.totalXP` exists to preserve. A brand new
/// user genuinely sits at Level 1 with 0 XP, and that should render as Level 1,
/// not as a spinner forever.
struct XPLevelCard: View {

    /// `nil` while the total has never been loaded on this device.
    let totalXP: Int?

    private var progress: XPLevel.Progress {
        XPLevel.progress(for: totalXP ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Level \(progress.level)")
                    .font(.manropeSemiBold(size: 20))
                    .foregroundColor(.wingmanBlack)

                Spacer()

                if let totalXP {
                    HStack(spacing: 4) {
                        Text("\(totalXP)")
                            .font(.manropeMedium(size: 14))
                            .foregroundColor(.wingmanBlack)
                        Text("XP")
                            .font(.manropeMedium(size: 12))
                            .foregroundColor(.gray)
                    }
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .wingmanBlack))
                        .scaleEffect(0.7)
                }
            }

            // Progress toward the next level. Full and unlabelled at the top of
            // the ladder, where there is nothing left to progress toward.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 10)
                    Capsule()
                        .fill(Color.wingmanBlack)
                        .frame(width: geo.size.width * progress.fraction, height: 10)
                        .animation(.easeInOut(duration: 0.35), value: progress.fraction)
                }
            }
            .frame(height: 10)

            HStack {
                if let toNext = progress.xpToNextLevel {
                    Text("\(toNext) XP to Level \(progress.level + 1)")
                        .font(.manropeMedium(size: 12))
                        .foregroundColor(.gray)
                } else {
                    Text("Max level reached")
                        .font(.manropeMedium(size: 12))
                        .foregroundColor(.gray)
                }

                Spacer()

                if let next = progress.nextLevelAt {
                    Text("\(next)")
                        .font(.manropeMedium(size: 12))
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

#Preview("Mid-ladder") {
    XPLevelCard(totalXP: 335).padding()
}

#Preview("Brand new — Level 1, 0 XP") {
    XPLevelCard(totalXP: 0).padding()
}

#Preview("Never loaded") {
    XPLevelCard(totalXP: nil).padding()
}

#Preview("Max level") {
    XPLevelCard(totalXP: 4200).padding()
}
