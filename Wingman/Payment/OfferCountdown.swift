//
//  OfferCountdown.swift
//  Wingman
//
//  Formatting for the second-chance discount clock, shared by the recovery
//  modal and the feature-gate paywall so the same deadline never renders two
//  different ways on two consecutive screens.
//

import Foundation

enum OfferCountdown {

    /// `m:ss` for anything under an hour, which the 30-minute window always is.
    ///
    /// Rounds UP, so the last second reads "0:01" rather than "0:00" for a
    /// whole second while the offer is still live. A clock that sits on zero
    /// while the button still works is the same broken promise as a clock that
    /// resets — just in the direction that costs trust instead of money.
    static func format(_ remaining: TimeInterval) -> String {
        let seconds = max(0, Int(remaining.rounded(.up)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}
