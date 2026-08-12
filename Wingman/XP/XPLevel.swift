//
//  XPLevel.swift
//  Wingman
//
//  Levels, derived from the XP total. Nothing is stored.
//

import Foundation

/// The level ladder from docs/xp-system-plan.md §0.
///
/// **Derived, never persisted.** A level is a pure function of `total_xp`,
/// which `get_xp_summary()` already returns, so there is no column to drift out
/// of step with the ledger. Rebalancing the ladder is an app release; it does
/// not need a data migration, because nothing was written down.
enum XPLevel {

    /// Cumulative XP required to *enter* each level. Index 0 is level 1.
    ///
    /// Gaps widen deliberately: 100, 150, 200, 250, 300, 400, 500, 600, 700,
    /// 800. Level 11 at 4,000 is roughly all 94 lessons plus all 15 scenarios
    /// played well, so the ladder is finishable from content but leans on daily
    /// practice and approach logs for an average player.
    static let thresholds: [Int] = [0, 100, 250, 450, 700, 1000, 1400, 1900, 2500, 3200, 4000]

    static var maxLevel: Int { thresholds.count }

    /// Where a user stands. All values are clamped so a negative or absurd
    /// total cannot produce a nonsense level or a progress bar outside 0…1.
    struct Progress: Equatable {
        /// 1-based, so the first level a user occupies reads as "Level 1".
        let level: Int
        let totalXP: Int
        /// XP at which this level began.
        let levelFloor: Int
        /// XP at which the next level begins. `nil` once the ladder is topped.
        let nextLevelAt: Int?

        var isMaxLevel: Bool { nextLevelAt == nil }

        /// XP earned since entering this level.
        var xpIntoLevel: Int { max(totalXP - levelFloor, 0) }

        /// Width of this level in XP. `nil` at max.
        var xpForLevel: Int? { nextLevelAt.map { $0 - levelFloor } }

        /// Still to earn before the next level. `nil` at max.
        var xpToNextLevel: Int? { nextLevelAt.map { max($0 - totalXP, 0) } }

        /// 0…1 for a progress bar. Always 1 at max level, so the bar reads
        /// "complete" rather than empty when the ladder is topped.
        var fraction: Double {
            guard let span = xpForLevel, span > 0 else { return 1 }
            return min(max(Double(xpIntoLevel) / Double(span), 0), 1)
        }
    }

    static func progress(for totalXP: Int) -> Progress {
        let xp = max(totalXP, 0)

        // Index of the highest threshold this total has reached.
        var index = 0
        for (i, threshold) in thresholds.enumerated() where xp >= threshold {
            index = i
        }

        let isTop = index == thresholds.count - 1
        return Progress(
            level: index + 1,
            totalXP: xp,
            levelFloor: thresholds[index],
            nextLevelAt: isTop ? nil : thresholds[index + 1]
        )
    }
}
