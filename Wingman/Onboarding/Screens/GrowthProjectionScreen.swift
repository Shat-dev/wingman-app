//
//  GrowthProjectionScreen.swift
//  Wingman
//
//  The animated "here's where this goes" projection screen — chart on top,
//  promise headline, three supporting rows, explicit Continue.
//
//  Unlike `StatisticScreen` this one uses a real button rather than the
//  tap-anywhere-on-the-right zone. The chart takes ~2s to finish drawing and
//  an invisible full-height tap target would let a fast tapper skip it
//  before it says anything; a button that is visibly there from the start is
//  both honest about the wait and skippable on purpose.
//

import SwiftUI

/// Copy for the projection screen. Separated from the view so the wording
/// can be swapped (or A/B'd) without touching layout.
struct GrowthProjectionContent {
    let headline: String
    let bullets: [Bullet]
    let positiveLabel: String
    let negativeLabel: String
    /// Source line under the bullets. Optional and **nil by default** — a
    /// citation should only appear here once someone has checked that the
    /// study says what the headline claims.
    let footnote: String?

    struct Bullet: Identifiable {
        let id = UUID()
        let systemImage: String
        /// Leading fragment rendered in the accent colour, e.g. "3x".
        let emphasis: String?
        let text: String
    }

    static let `default` = GrowthProjectionContent(
        headline: "Build the confidence to take action when it matters",
        bullets: [
            Bullet(
                systemImage: "figure.run",
                emphasis: "3x",
                text: "faster progress than watching generic advice videos"
            ),
            Bullet(
                systemImage: "book.fill",
                emphasis: nil,
                text: "Bite-sized lessons you can do on your commute or lunch break"
            ),
            Bullet(
                systemImage: "brain.head.profile",
                emphasis: nil,
                text: "Science-based techniques that actually stick"
            )
        ],
        positiveLabel: "Using Wingman every day",
        negativeLabel: "Doing nothing",
        footnote: nil
    )
}

struct GrowthProjectionScreen: View {
    var content: GrowthProjectionContent = .default
    let onContinue: () -> Void

    /// The headline and bullets fade up just behind the line as it draws,
    /// so the eye is on the chart first and the claim second.
    @State private var showCopy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            GrowthChartView(
                positiveLabel: content.positiveLabel,
                negativeLabel: content.negativeLabel
            )

            Spacer().frame(height: UIScreen.isSmallPhone ? 16 : 28)

            Text(content.headline)
                .font(.manropeSemiBold(size: UIScreen.isSmallPhone ? 21 : 24))
                .foregroundColor(.wingmanBlack)
                .lineSpacing(3)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(showCopy ? 1 : 0)
                .offset(y: showCopy ? 0 : 8)

            Spacer().frame(height: UIScreen.isSmallPhone ? 16 : 24)

            VStack(alignment: .leading, spacing: 18) {
                ForEach(content.bullets) { bullet in
                    bulletRow(bullet)
                }
            }

            if let footnote = content.footnote {
                Spacer().frame(height: 20)
                Text(footnote)
                    .font(.manropeRegular(size: 11))
                    .foregroundColor(.gray.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 24)

            Button(action: {
                HapticManager.shared.tap()
                onContinue()
            }) {
                Text("Continue")
                    .font(.manropeSemiBold(size: 17))
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.wingmanBlack)
                    .foregroundColor(.wingmanWhiteFF)
                    .cornerRadius(5)
            }
            .buttonStyle(ScalePressStyle())
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
        .onAppear {
            withAnimation(.easeOut(duration: 0.45).delay(0.55)) {
                showCopy = true
            }
        }
    }

    private func bulletRow(_ bullet: GrowthProjectionContent.Bullet) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: bullet.systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.customGreen)
                .frame(width: 24, alignment: .center)
                .padding(.top, 1)

            Group {
                if let emphasis = bullet.emphasis {
                    // Concatenated rather than two `Text`s in an HStack so the
                    // emphasis stays inline when the sentence wraps.
                    Text(emphasis)
                        .font(.manropeBold(size: 15))
                        .foregroundColor(.customGreen)
                    + Text(" " + bullet.text)
                        .font(.manropeRegular(size: 15))
                        .foregroundColor(.wingmanBlack)
                } else {
                    Text(bullet.text)
                        .font(.manropeRegular(size: 15))
                        .foregroundColor(.wingmanBlack)
                }
            }
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .opacity(showCopy ? 1 : 0)
        .offset(y: showCopy ? 0 : 8)
    }
}

#Preview {
    GrowthProjectionScreen(onContinue: {})
        .background(Color.white)
}
