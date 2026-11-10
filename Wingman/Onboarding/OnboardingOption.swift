//
//  OnboardingOption.swift
//  Wingman
//
//  Every answer a user can pick in onboarding, defined once.
//
//  An option used to be a single string that did three jobs: it was the label
//  on the button, the value written to UserDefaults / PostHog / Supabase, and
//  the thing the paywall and the reminders switched on. That makes the label
//  untranslatable — change the wording and the stored value, every analytics
//  breakdown and every `switch` change with it.
//
//  Here the three jobs are separate:
//
//    - the enum case (its `rawValue` is the `id`) is what code compares;
//    - `canonicalValue` is what is stored and sent. These are the exact
//      English strings the app has always written, frozen — including the
//      "embarrased" misspelling. They are data now, not copy: never edit one,
//      never show one. `OnboardingCanonicalValuesTests` pins them.
//    - `label` is what the user reads, and the only one of the three that may
//      be reworded or translated. It is `englishLabel` passed through
//      `L10n.content`, so it is English until a translation exists.
//
//  `nonisolated` because `MarketingNotifications` (a nonisolated enum) reads
//  these off the main actor when it schedules the reminders.
//

import Foundation

/// One selectable answer, as the question screen and the answer store see it.
nonisolated struct OnboardingOption: Identifiable, Hashable, Sendable {
    /// Stable identifier. Never shown, never stored on its own.
    let id: String
    /// The frozen English string written to UserDefaults, PostHog and Supabase.
    let canonicalValue: String
    /// What the user reads on the button.
    let label: String
}

/// A question's answers as a typed enum, so the personalisation code can
/// `switch` on cases instead of on display text.
nonisolated protocol OnboardingOptionKind: RawRepresentable, CaseIterable, Sendable where RawValue == String {
    /// The onboarding question this set of answers belongs to — the `<key>`
    /// in `onboarding_<key>`.
    static var questionKey: String { get }
    /// See `OnboardingOption.canonicalValue`.
    var canonicalValue: String { get }
    /// The English wording shown for the option. Usually the same text as
    /// `canonicalValue`, but a different thing: this one may be reworded.
    var englishLabel: String { get }
}

nonisolated extension OnboardingOptionKind {
    /// The English wording shown for this option. The stored value, unless a
    /// case says otherwise.
    var englishLabel: String { canonicalValue }

    /// `englishLabel` in the language the app is running in, falling back to
    /// English. Display only — see `L10n.content`.
    var label: String { L10n.content(englishLabel) }

    var option: OnboardingOption {
        OnboardingOption(id: rawValue, canonicalValue: canonicalValue, label: label)
    }

    /// Every answer to this question, in display order.
    static var options: [OnboardingOption] {
        allCases.map(\.option)
    }

    /// The case a stored answer refers to. Nil for nil, for values this build
    /// no longer offers (the legacy "45+"), and for anything unrecognised —
    /// callers treat nil as "no personalisation", which is what an unmatched
    /// string always meant.
    init?(storedValue: String?) {
        guard let storedValue,
              let match = Self.allCases.first(where: { $0.canonicalValue == storedValue }) else {
            return nil
        }
        self = match
    }
}

// MARK: - "What brought you to Wingman?" (multi-select)

nonisolated enum MotivationOption: String, OnboardingOptionKind {
    case breakup
    case freeze
    case doneWithApps = "done_with_apps"
    case onMyOwn = "on_my_own"
    case moreConfidence = "more_confidence"
    case other

    static let questionKey = "motivation"

    var canonicalValue: String {
        switch self {
        case .breakup:        return "Back on the market after a breakup or divorce"
        case .freeze:         return "I freeze up around women I find attractive"
        case .doneWithApps:   return "Done with dating apps"
        case .onMyOwn:        return "Tired of being on my own"
        case .moreConfidence: return "Want more confidence in general"
        case .other:          return "Other"
        }
    }
}

// MARK: - "How old are you?"

nonisolated enum AgeOption: String, OnboardingOptionKind {
    case age18to24 = "18_24"
    case age25to34 = "25_34"
    case age35to44 = "35_44"
    case age45to54 = "45_54"
    case age55plus = "55_plus"

    static let questionKey = "age"

    var canonicalValue: String {
        switch self {
        case .age18to24: return "18-24"
        case .age25to34: return "25-34"
        case .age35to44: return "35-44"
        case .age45to54: return "45-54"
        case .age55plus: return "55+"
        }
    }
}

// MARK: - "When was the last time you spoke to a woman in public?"

nonisolated enum LastApproachOption: String, OnboardingOptionKind {
    case pastWeek = "past_week"
    case pastMonth = "past_month"
    case fewMonths = "few_months"
    case overAYear = "over_a_year"
    case never

    static let questionKey = "last_approach"

    var canonicalValue: String {
        switch self {
        case .pastWeek:  return "Within the past week"
        case .pastMonth: return "Within the past month"
        case .fewMonths: return "A few months ago"
        case .overAYear: return "More than a year ago"
        case .never:     return "Never approached before"
        }
    }
}

// MARK: - "Do you often want to talk to women but don't?"

nonisolated enum ApproachFrequencyOption: String, OnboardingOptionKind {
    case everyTime = "every_time"
    case mostTimes = "most_times"
    case sometimes
    case rarely
    case usuallyGoForIt = "usually_go_for_it"

    static let questionKey = "approach_frequency"

    var canonicalValue: String {
        switch self {
        case .everyTime:      return "Every time"
        case .mostTimes:      return "Most times"
        case .sometimes:      return "Sometimes"
        case .rarely:         return "Rarely"
        case .usuallyGoForIt: return "No, I usually go for it"
        }
    }
}

// MARK: - "What usually stops you from doing so?" (multi-select)

nonisolated enum BarrierOption: String, OnboardingOptionKind {
    case fearOfRejection = "fear_of_rejection"
    case socialConsequences = "social_consequences"
    case whatToSay = "what_to_say"
    case comingAcrossWrong = "coming_across_wrong"
    case other

    static let questionKey = "barriers"

    var canonicalValue: String {
        switch self {
        // Misspelled on purpose. This is the value every existing answer was
        // stored under; users read the corrected `englishLabel` below.
        case .fearOfRejection:    return "Fear of rejection or being embarrased"
        case .socialConsequences: return "Fear of social consequences"
        case .whatToSay:          return "Not knowing what to say or how to start"
        case .comingAcrossWrong:  return "Worrying about coming across wrong"
        case .other:              return "Other"
        }
    }

    var englishLabel: String {
        switch self {
        case .fearOfRejection: return "Fear of rejection or being embarrassed"
        default:               return canonicalValue
        }
    }
}

// MARK: - "What are you mainly hoping to improve?" (multi-select)

nonisolated enum GoalOption: String, OnboardingOptionKind {
    case mindsetAndConfidence = "mindset_and_confidence"
    case howToApproach = "how_to_approach"
    case conversationsGoing = "conversations_going"
    case attraction
    case other

    static let questionKey = "goals"

    var canonicalValue: String {
        switch self {
        case .mindsetAndConfidence: return "Better mindset & confidence"
        case .howToApproach:        return "Learning how to approach"
        case .conversationsGoing:   return "Keeping conversations going"
        case .attraction:           return "Creating attraction and romantic interest"
        case .other:                return "Other"
        }
    }
}

// MARK: - Stored answers

/// How a selection becomes the stored answer and back. Pure functions, so the
/// round trip is unit-tested without the view.
nonisolated enum OnboardingAnswerCoding {
    /// Multi-select answers are stored joined with this, in tap order. No
    /// multi-select `canonicalValue` may contain it
    /// (`OnboardingCanonicalValuesTests` checks).
    static let separator = ", "

    /// The value to store and send for a selection of option ids, in the order
    /// given. Ids that are not in `options` are dropped; an empty result means
    /// there is nothing to store.
    static func storedValue(forSelectedIDs ids: [String], in options: [OnboardingOption]) -> String {
        ids.compactMap { id in options.first { $0.id == id }?.canonicalValue }
            .joined(separator: separator)
    }

    /// The option ids a stored answer selects, limited to options still on
    /// offer. An answer stored by an older build can name an option that has
    /// since been removed ("45+", before it was split in two); restoring that
    /// would enable Next with nothing highlighted and re-submit a value the
    /// user can't see on screen.
    ///
    /// Only multi-select answers are split. Splitting every answer was wrong
    /// for one single-select value — "No, I usually go for it" came back as
    /// two fragments that matched nothing.
    static func selectedIDs(fromStoredValue stored: String, in options: [OnboardingOption], isMultiSelect: Bool) -> [String] {
        let values = isMultiSelect ? stored.components(separatedBy: separator) : [stored]
        return values.compactMap { value in options.first { $0.canonicalValue == value }?.id }
    }

    /// The first pick of a stored answer — the one treated as mattering most
    /// when an answer drives personalised copy. For a single-select answer
    /// callers pass the whole value instead.
    static func firstPick(ofStoredValue stored: String?) -> String? {
        stored?.components(separatedBy: separator).first
    }
}
