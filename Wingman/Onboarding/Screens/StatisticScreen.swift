//
//  StatisticScreen.swift
//  Wingman
//
//  Between-question interstitial that presents a single statistic + image.
//  The right half of the screen is a tap-to-continue zone (the
//  `TapToContinueButton` label at bottom-right is a visual hint only — the
//  full right half accepts taps once visible). The left half explicitly
//  no-ops to avoid accidental progression from the back-button side.
//

import SwiftUI

struct StatisticScreen: View {
    let statistic: StatisticContent
    let onContinue: () -> Void

    var body: some View {
        // Top-anchored ZStack so that if the inner content ever exceeds the
        // available vertical space (long headings / facts / large Dynamic
        // Type), the overflow drops downward and gets clipped at the bottom
        // rather than climbing upward into the top bar area — which is what
        // previously caused the progress bar to appear higher on statistic
        // screens with longer copy (e.g. the 25+ age branch).
        ZStack(alignment: .top) {
            Color.white

            VStack(spacing: 0) {
                // Main statistic content
                VStack(spacing: 20) {
                    // Heading
                    Text(statistic.heading)
                        .font(.manropeSemiBold(size: 24))
                        .foregroundColor(.wingmanBlack)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Subheading
                    Text(statistic.subheading)
                        .font(.manropeRegular(size: 16))
                        .foregroundColor(.gray)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Spacer().frame(height: 40)

                    // Image — reduced from 250pt to 220pt to free up
                    // ~30pt of vertical room for the `.fixedSize`-expanded
                    // text above/below. Without this headroom, the longer
                    // else-branch heading+fact would push the outer view
                    // past its proposed size and trigger center-overflow,
                    // shifting the top bar up by 13pt on statistic screens.
                    Image(statistic.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 220)

                    Spacer().frame(height: 40)

                    // Fact
                    Text(statistic.fact)
                        .font(.manropeRegular(size: 16))
                        .foregroundColor(.gray)
                        .lineSpacing(4)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer() // push content up so the button sits at bottom
                }
                .padding(.horizontal, 24)

                // Bottom-right Tap to Continue
                HStack {
                    Spacer()
                    TapToContinueButton {
                        onContinue()
                    }
                    // make the tappable area a little larger
                    .padding(.trailing, 4)
                    .font(.manropeMedium(size: 14))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }

            // Invisible overlay to control tap areas - only right side should progress
            HStack(spacing: 0) {
                // Left half - blocks any tap gestures, not tappable for progression
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Explicitly do nothing - left side should not progress
                        log("🚫 Left side tapped - no action")
                    }

                // Right half - tappable area for progression
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        log("✅ Right side tapped - continuing")
                        HapticManager.shared.tap()
                        onContinue()
                    }
            }
        }
    }
}

#Preview("Short copy") {
    StatisticScreen(
        statistic: StatisticContent.for(questionKey: "approach_frequency", ageGroup: "18-24")!,
        onContinue: {}
    )
}

#Preview("Long copy (25+ branch)") {
    StatisticScreen(
        statistic: StatisticContent.for(questionKey: "last_approach", ageGroup: "25-34")!,
        onContinue: {}
    )
}
