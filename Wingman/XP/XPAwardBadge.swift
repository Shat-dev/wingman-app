//
//  XPAwardBadge.swift
//  Wingman
//
//  The "+35 XP" that appears on a completion screen.
//

import SwiftUI

/// Shows what the completion just earned, or nothing at all.
///
/// **Confirmed awards only.** It renders when the server has said `awarded ==
/// true`, never optimistically. The plan (§5.2) originally called for showing a
/// locally-predicted amount immediately and withdrawing it on a replay; that is
/// a number appearing and then vanishing, which is worse than a short wait —
/// and for approaches the local prediction cannot know about the daily cap, so
/// it would be wrong exactly when it mattered. Instead the badge animates in
/// when the result lands, which reads as the reward arriving.
///
/// Consequences, both acceptable:
///   - Offline, nothing shows here. The award is queued and the total updates
///     when it flushes.
///   - Tapping Continue faster than the round trip means not seeing it. The
///     total on Home and Profile is still correct.
///
/// Used by all three completion screens. It is deliberately the *only* thing
/// they share: unifying the screens themselves would mean normalising a 290 vs
/// 291pt image, a 24 vs 28pt title and a system vs Manrope button, i.e.
/// redesigning two screens under cover of a refactor.
struct XPAwardBadge: View {

    let award: XPStore.Award?

    var body: some View {
        Group {
            if let award {
                HStack(spacing: 6) {
                    Text("+\(award.amount)")
                        .font(.manropeSemiBold(size: 20))
                    Text("XP")
                        .font(.manropeMedium(size: 14))
                        .opacity(0.6)
                }
                .foregroundColor(.wingmanBlack)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.wingmanBlack.opacity(0.15), lineWidth: 1)
                )
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: award)
    }
}

#Preview("Awarded") {
    XPAwardBadge(award: XPStore.Award(source: .lesson, amount: 35, totalAfter: 335))
}

#Preview("Nothing (replay, capped, or still in flight)") {
    XPAwardBadge(award: nil)
}
