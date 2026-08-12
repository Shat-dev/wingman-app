//
//  ProfileStatsHeader.swift
//  Wingman
//
//  Profile's identity block and the three stat tiles beneath it.
//
//  WHY THE WEEK-OF-FLAMES WENT
//
//  `WeekStreakCard` showed seven flame slots for the current week plus a
//  current/total pair. It answered "which days did you practise this week",
//  which is a narrower question than the screen wants to answer, and it took
//  the most vertical space on Profile to do it. Replaced by a single all-time
//  best, which is the number a user actually quotes about themselves.
//
//  ON THE COLOUR
//
//  Three accents appear here for the first time outside onboarding, and they
//  are the growth chart's own (GrowthChartView.swift:178-180) rather than
//  anything new. They mark the three stat categories apart from one another and
//  do nothing else. Progress stays black: the level bar here and the one on the
//  completion screen are the same object doing the same job, so they look the
//  same. Colour names the category, black measures the distance.
//

import SwiftUI

// MARK: - Identity + level

/// Avatar, name, level, and the bar showing the distance to the next one.
///
/// Absorbs what `XPLevelCard` used to do as a separate card further down the
/// page. Level is a derivation of the XP total (see `XPLevel`), so putting it
/// against the user's own name reads as a property of them rather than as
/// another statistic in a list.
struct ProfileIdentityCard: View {

    let displayName: String?
    /// `nil` while the total has never loaded on this device.
    let totalXP: Int?
    let onTap: () -> Void

    private var progress: XPLevel.Progress {
        XPLevel.progress(for: totalXP ?? 0)
    }

    /// Under 15 words, and specific about what is left rather than vague about
    /// what has been achieved.
    private var levelLine: String {
        guard totalXP != nil else { return "Level 1" }
        guard let toNext = progress.xpToNextLevel else {
            return "Level \(progress.level) · Max level reached"
        }
        return "Level \(progress.level) · \(toNext) XP to Level \(progress.level + 1)"
    }

    var body: some View {
        VStack(spacing: 16) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    Image("onboard_img_1")
                        .resizable()
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 4) {
                        // Placeholder rather than a blank row when no name is
                        // set, so the card reads as editable rather than broken.
                        // Guests reach Profile without ever being asked, so this
                        // is the common state, not an edge case.
                        if let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
                           !name.isEmpty {
                            Text(name)
                                .font(.manropeMedium(size: 18))
                                .foregroundColor(.wingmanBlack)
                        } else {
                            Text("Add your name")
                                .font(.manropeMedium(size: 18))
                                .foregroundColor(Color.wingmanBlack.opacity(0.4))
                        }

                        Text(levelLine)
                            .font(.manropeMedium(size: 13))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
            }
            .buttonStyle(ScalePressStyle())

            // Same treatment as the completion screen's bar, deliberately.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 6)
                    Capsule()
                        .fill(Color.wingmanBlack)
                        .frame(width: geo.size.width * progress.fraction, height: 6)
                        .animation(.easeInOut(duration: 0.35), value: progress.fraction)
                }
            }
            .frame(height: 6)
        }
    }
}

// MARK: - Stat tiles

/// One number and what it counts.
struct ProfileStatTile: View {

    let icon: String
    let tint: Color
    /// `nil` renders an em-dash placeholder rather than a misleading 0 — the
    /// same "not loaded yet is not zero" distinction the stores preserve.
    let value: Int?
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(tint)
            }

            Text(value.map(String.init) ?? "–")
                .font(.manropeSemiBold(size: 22))
                .monospacedDigit()
                .foregroundColor(.wingmanBlack)

            Text(label)
                .font(.manropeMedium(size: 12))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

/// The three tiles, in the order a user cares about them: habit, effort, output.
struct ProfileStatTiles: View {

    let topStreak: Int?
    let totalXP: Int?
    let lessonsCompleted: Int?

    var body: some View {
        HStack(spacing: 12) {
            ProfileStatTile(icon: "flame.fill", tint: .accentClay,
                            value: topStreak, label: "Top streak")
            ProfileStatTile(icon: "bolt.fill", tint: .accentIndigo,
                            value: totalXP, label: "XP points")
            ProfileStatTile(icon: "book.closed.fill", tint: .accentGreen,
                            value: lessonsCompleted, label: "Lessons")
        }
    }
}

#Preview("Identity") {
    VStack(spacing: 24) {
        ProfileIdentityCard(displayName: "Arthur", totalXP: 152, onTap: {})
        ProfileStatTiles(topStreak: 4, totalXP: 152, lessonsCompleted: 12)
    }
    .padding(20)
}

#Preview("Nothing loaded yet") {
    VStack(spacing: 24) {
        ProfileIdentityCard(displayName: nil, totalXP: nil, onTap: {})
        ProfileStatTiles(topStreak: nil, totalXP: nil, lessonsCompleted: 0)
    }
    .padding(20)
}
