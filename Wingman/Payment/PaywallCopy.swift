//
//  PaywallCopy.swift
//  Wingman
//
//  Copy for the onboarding/feature-gate paywall, written from the user's own
//  onboarding answers. (The one-time offer used these ticks too until Nov 2026.)
//  It sells who they become, not what they unlock: each tick names the pain
//  they told us about and states it solved.
//
//  Keys are the stored answer values (`onboarding_<questionKey>`), which are
//  the raw option strings in OnboardingFlow — including the deliberate
//  "embarrased" misspelling. Anything unrecognised, skipped, or from an older
//  build falls back to a line that fits everyone, so the list is always three
//  long. Multi-select answers are stored ", "-joined in tap order; the first
//  pick is treated as the one that matters most.
//
//  Each tick is kept to 36 characters or fewer so it sits on one line at
//  16pt on a 375pt-wide phone (SE, 13 mini). Longer lines wrap there and push
//  the last tick under the plan cards.
//

import Foundation

enum PaywallCopy {

    /// The main paywall's single page. The headline pairs with the "day 1"
    /// calendar illustration.
    static var mainPage: PaywallPage {
        PaywallPage(
            imageName: "paywall_1",
            headline: "Day 1 of becoming the guy who goes for it",
            bullets: personalTicks(closing: "No more \u{201C}what if\u{201D} moments")
        )
    }

    /// The one-time offer's ticks. Its subtitle already asks the "what if"
    /// question, so it closes on the identity instead.
    private static func personalTicks(closing: String) -> [String] {
        let defaults = UserDefaults.standard
        return [
            barrierLine(firstPick(defaults.string(forKey: "onboarding_barriers"))),
            goalLine(firstPick(defaults.string(forKey: "onboarding_goals"))),
            closing
        ]
    }

    private static func firstPick(_ stored: String?) -> String? {
        stored?.components(separatedBy: ", ").first
    }

    /// Answer to "What usually stops you from doing so?"
    static func barrierLine(_ answer: String?) -> String {
        switch answer {
        case "Fear of rejection or being embarrased":
            return "Stop letting fear of rejection win"
        case "Fear of social consequences":
            return "Stop caring what others think"
        case "Not knowing what to say or how to start":
            return "Know exactly how to start talking"
        case "Worrying about coming across wrong":
            return "Come across natural, not nervous"
        default:
            return "Stop talking yourself out of it"
        }
    }

    /// Answer to "What are you mainly hoping to improve?"
    static func goalLine(_ answer: String?) -> String {
        switch answer {
        case "Better mindset & confidence":
            return "Feel confident, not anxious"
        case "Learning how to approach":
            return "Walk up to her without hesitating"
        case "Keeping conversations going":
            return "Keep it flowing, no awkward silences"
        case "Creating attraction and romantic interest":
            return "Turn small talk into real chemistry"
        default:
            return "Go first without overthinking it"
        }
    }
}
