//
//  XPSource.swift
//  Wingman
//
//  The kinds of work that earn XP, and the local mirror of what each is worth.
//

import Foundation

/// A thing a user can do that earns XP.
///
/// Raw values are the `source_type` primary keys in `public.xp_rules`
/// (migration 20260811161839_xp_ledger.sql). `award_xp` raises on an unknown
/// source type rather than silently awarding nothing, so this enum and that
/// table have to move together — adding a case here without a matching row is
/// a runtime error, by design.
enum XPSource: String, CaseIterable {
    case dailyPractice = "daily_practice"
    case lesson        = "lesson"
    case scenario      = "scenario"
    case approach      = "approach"

    // NO LOCAL COPY OF THE AMOUNTS, DELIBERATELY.
    //
    // An earlier revision carried a `Formula` mirror of `public.xp_rules`
    // (base / per-correct / perfect-bonus / daily-cap) to support optimistic
    // display. Phase 3 settled on rendering only confirmed awards — see
    // XPAwardBadge — which left that mirror with no callers, and an unexercised
    // hardcoded duplicate of the economy is worse than none: it drifts silently
    // from `xp_rules` and is wrong the day somebody wires it up. It was removed
    // rather than kept "just in case".
    //
    // The client sends `correct_count` and `question_count`; the server decides
    // what they are worth. That is the whole point of the design, and it is why
    // amounts can be retuned with an UPDATE instead of an App Store release.
    //
    // If optimistic display is ever wanted, read the amounts from `xp_rules` at
    // runtime — the table already has a SELECT policy for `authenticated` — and
    // treat the local values as a cold-start fallback only.
}

/// The client-local calendar day, as the ledger records it.
///
/// Deliberately **not** shared with `DailyPracticeService.getCurrentLocalDate()`
/// even though both produce "yyyy-MM-dd" for the same instant, for two reasons:
///
///   1. Phase 2 must not touch the streak files at all. See
///      docs/xp-system-plan.md §4.5.
///   2. That formatter sets no locale, so it inherits the device's calendar.
///      On a device set to a non-Gregorian calendar (Buddhist, Japanese
///      imperial, …) `yyyy` is not the Gregorian year, and the streak has been
///      writing e.g. `2569-08-12` into `user_daily_practice_sessions.date` for
///      those users. It stays self-consistent — every comparison uses the same
///      formatter — so the streak still works, but the stored dates are wrong.
///      This one pins `en_US_POSIX` + Gregorian so the ledger is right
///      regardless of device settings.
///
/// The consequence of the divergence is nil in practice: `source_id` only has
/// to be stable per user per day for the once-a-day rule to hold, and it is.
enum XPLocalDate {

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Today in the device's timezone, as `yyyy-MM-dd`.
    static func today(_ date: Date = Date()) -> String {
        // Re-read the timezone on every call: the cached formatter outlives a
        // user crossing a timezone boundary mid-session, and a stale zone would
        // put an award on the wrong day.
        formatter.timeZone = .current
        return formatter.string(from: date)
    }
}
