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

                    // `maxHeight` rather than an exact height so these two
                    // gaps are the first thing to give on a short canvas.
                    // A Spacer has no intrinsic size, so it still takes the
                    // full 40 wherever there is room — but when there isn't,
                    // 80pt of pure whitespace collapsing is a far better
                    // trade than the illustration shrinking to a thumbnail.
                    Spacer().frame(maxHeight: 40)

                    // Image — reduced from 250pt to 220pt to free up
                    // ~30pt of vertical room for the `.fixedSize`-expanded
                    // text above/below. Without this headroom, the longer
                    // else-branch heading+fact would push the outer view
                    // past its proposed size and trigger center-overflow,
                    // shifting the top bar up by 13pt on statistic screens.
                    //
                    // Deliberately a *flexible* frame rather than
                    // `.frame(height: 220)`. Every other element in this
                    // stack is rigid — the three `Text`s are `.fixedSize`d
                    // vertically and the two gaps are exact — so when the
                    // canvas is too short something has to give, and with a
                    // hard 220 the only thing that could was the screen's own
                    // bounds: the chevron and progress bar were pushed off
                    // the top edge and "Tap to continue" off the bottom.
                    //
                    // That is not hypothetical. Display Zoom (Settings →
                    // Display & Brightness) shrinks the whole UI's *point*
                    // canvas — a 6.1" iPhone goes from 390×844 to 320×693 —
                    // and there is no API to opt out of it. A stock iPhone SE
                    // at 375×667 overflowed here too, with no zoom involved.
                    //
                    // idealHeight keeps this at exactly 220 wherever there is
                    // room, so nothing moves on the canvases that already
                    // worked. Note `maxHeight: 220` alone would NOT work: the
                    // frame would then size to the aspect-fitted artwork
                    // (~157pt here, since these images are wider than they
                    // are tall) and shift everything below it up on *every*
                    // device.
                    //
                    // The 120 floor stops it collapsing. Left to shrink
                    // freely it bottomed out near 50pt at 320×693, because a
                    // VStack splits a shortfall across its flexible children
                    // and the trailing `Spacer()` was claiming its share —
                    // legible, but a thumbnail. Floored here and with the two
                    // gaps above/below now collapsible, the illustration
                    // keeps a sensible size and the whitespace absorbs the
                    // difference instead.
                    Image(statistic.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(minHeight: 120, idealHeight: 220, maxHeight: 220)

                    // `maxHeight` rather than an exact height so these two
                    // gaps are the first thing to give on a short canvas.
                    // A Spacer has no intrinsic size, so it still takes the
                    // full 40 wherever there is room — but when there isn't,
                    // 80pt of pure whitespace collapsing is a far better
                    // trade than the illustration shrinking to a thumbnail.
                    Spacer().frame(maxHeight: 40)

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
