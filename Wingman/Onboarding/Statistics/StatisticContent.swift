//
//  StatisticContent.swift
//  Wingman
//

import SwiftUI
import UIKit  // for UIImage.preparingForDisplay() asset decode warmup

struct StatisticContent: Hashable {
    let heading: String
    let subheading: String
    let imageName: String
    let fact: String
}

extension StatisticContent {
    /// Catalog lookup for the statistic shown between questions.
    /// Returns `nil` when a question has no associated statistic.
    static func `for`(questionKey: String, ageGroup: String) -> StatisticContent? {

        // After "last_approach" question
        if questionKey == "last_approach" {
            if ageGroup == "18-24" {
                return StatisticContent(
                    heading: "Almost half of men your age have never approached a women",
                    subheading: "You are not alone. Millions of men struggle with approaching.",
                    imageName: "stat_never_approached",
                    fact: "45% of men aged 18-24 have never approached a woman"
                )
            } else {
                return StatisticContent(
                    heading: "Almost half of men your age haven't approached in the past year",
                    subheading: "You are not alone. Millions of men struggle with approaching.",
                    imageName: "stat_never_approached",
                    fact: "48% of men aged 26-40 haven't approached in the past year"
                )
            }
        }

        // After "frequency" question
        if questionKey == "approach_frequency" {
            return StatisticContent(
                heading: "Most woman want to be talked to more",
                subheading: "They're just waiting for you to make the first move",
                imageName: "stat_frequency",
                fact: "77% of women aged between 18 and 30 want to be approached more"
            )
        }

        // After "barriers" question
        if questionKey == "barriers" {
            return StatisticContent(
                heading: "Most men regret the chances they didn't make",
                subheading: "Don't join that statistic. Your future self is counting on you.",
                imageName: "stat_regret",
                fact: "63% of single men regret not approaching women when they were younger"
            )
        }

        // After "goals" question
        if questionKey == "goals" {
            return StatisticContent(
                heading: "Half of men don't approach. Most who do, succeed.",
                subheading: "Which side do you want to be on?",
                imageName: "stat_success",
                fact: "58% of men who consistently approach get a number, date, or relationship"
            )
        }

        return nil
    }

    /// Force-decode a named asset off the main thread so the bitmap is ready
    /// by the time SwiftUI constructs the `Image`. Idempotent — UIKit caches
    /// the prepared image. No-op on failure (the `Image` will still resolve,
    /// just without the pre-warm benefit).
    static func warmImage(named name: String) {
        Task.detached(priority: .userInitiated) {
            _ = UIImage(named: name)?.preparingForDisplay()
        }
    }
}
