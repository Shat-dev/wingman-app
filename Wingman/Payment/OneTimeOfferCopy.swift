//
//  OneTimeOfferCopy.swift
//  Wingman
//
//  The sentences on the one-time offer that mention how long the discount
//  lasts and what the plan renews into.
//
//  They used to be built from pieces: a helper returned "year", "2 years",
//  "month" or "6 months", and that word was dropped into "off your first …",
//  "for your first …" and "… billed today for your first …, then …/…".
//  A piece like "year" cannot be translated on its own (its form depends on
//  the sentence around it), and the sentence around it fixed English word
//  order for every language.
//
//  Each case is now a whole sentence of its own in the catalog, with only
//  prices and numbers as placeholders. The English text of every case is
//  exactly what the pieces used to produce.
//
//  Lengths are read from StoreKit (see StoreProduct+IntroDiscount); nothing
//  here assumes "a year".
//

import Foundation

nonisolated enum OneTimeOfferCopy {

    /// A length of time as the offer copy talks about it: whole years when
    /// the months divide by twelve, months otherwise.
    enum Duration: Equatable {
        case years(Int)
        case months(Int)

        init(months: Int) {
            self = months % 12 == 0 ? .years(months / 12) : .months(months)
        }
    }

    // MARK: - Under the big number

    /// Under the percentage: "off your first year".
    static func discountLine(first duration: Duration) -> String {
        switch duration {
        case .years(1):
            return String(localized: "off your first year", comment: "One-time offer, under the big percentage (\"50%\").")
        case .years(let years):
            return String(localized: "off your first \(years) years", comment: "One-time offer, under the big percentage. %lld is a number of years, 2 or more.")
        case .months(1):
            return String(localized: "off your first month", comment: "One-time offer, under the big percentage (\"50%\").")
        case .months(let months):
            return String(localized: "off your first \(months) months", comment: "One-time offer, under the big percentage. %lld is a number of months, 2 or more.")
        }
    }

    /// Under the price, when no trustworthy percentage exists:
    /// "for your first year".
    static func priceLine(first duration: Duration) -> String {
        switch duration {
        case .years(1):
            return String(localized: "for your first year", comment: "One-time offer, under the discounted price (\"$34.99\").")
        case .years(let years):
            return String(localized: "for your first \(years) years", comment: "One-time offer, under the discounted price. %lld is a number of years, 2 or more.")
        case .months(1):
            return String(localized: "for your first month", comment: "One-time offer, under the discounted price (\"$34.99\").")
        case .months(let months):
            return String(localized: "for your first \(months) months", comment: "One-time offer, under the discounted price. %lld is a number of months, 2 or more.")
        }
    }

    // MARK: - Disclosure under the button

    /// What is charged today, for how long, what it renews into, and how to
    /// cancel: "$34.99 billed today for your first year, then $69.99/year.
    /// Cancel anytime in App Store settings."
    ///
    /// A plan that renews every year or every month has its own sentence for
    /// each kind of discount length. Anything else (a plan renewing every
    /// six months, say) is something this app does not sell: English keeps
    /// the wording it has always produced for it, and a translated app shows
    /// a complete sentence that states both prices without the lengths.
    static func disclosure(introPrice: String, first: Duration, fullPrice: String, renewal: Duration) -> String {
        switch (first, renewal) {

        // Renews yearly
        case (.years(1), .years(1)):
            return String(
                localized: "\(introPrice) billed today for your first year, then \(fullPrice)/year. Cancel anytime in App Store settings.",
                comment: "One-time offer, under the button. First %@: the discounted price charged today. Second %@: the regular yearly price."
            )
        case (.years(let years), .years(1)):
            return String(
                localized: "\(introPrice) billed today for your first \(years) years, then \(fullPrice)/year. Cancel anytime in App Store settings.",
                comment: "One-time offer, under the button. First %@: the discounted price charged today. %lld: years the discount lasts, 2 or more. Second %@: the regular yearly price."
            )
        case (.months(1), .years(1)):
            return String(
                localized: "\(introPrice) billed today for your first month, then \(fullPrice)/year. Cancel anytime in App Store settings.",
                comment: "One-time offer, under the button. First %@: the discounted price charged today. Second %@: the regular yearly price."
            )
        case (.months(let months), .years(1)):
            return String(
                localized: "\(introPrice) billed today for your first \(months) months, then \(fullPrice)/year. Cancel anytime in App Store settings.",
                comment: "One-time offer, under the button. First %@: the discounted price charged today. %lld: months the discount lasts, 2 or more. Second %@: the regular yearly price."
            )

        // Renews monthly
        case (.years(1), .months(1)):
            return String(
                localized: "\(introPrice) billed today for your first year, then \(fullPrice)/month. Cancel anytime in App Store settings.",
                comment: "One-time offer, under the button. First %@: the discounted price charged today. Second %@: the regular monthly price."
            )
        case (.years(let years), .months(1)):
            return String(
                localized: "\(introPrice) billed today for your first \(years) years, then \(fullPrice)/month. Cancel anytime in App Store settings.",
                comment: "One-time offer, under the button. First %@: the discounted price charged today. %lld: years the discount lasts, 2 or more. Second %@: the regular monthly price."
            )
        case (.months(1), .months(1)):
            return String(
                localized: "\(introPrice) billed today for your first month, then \(fullPrice)/month. Cancel anytime in App Store settings.",
                comment: "One-time offer, under the button. First %@: the discounted price charged today. Second %@: the regular monthly price."
            )
        case (.months(let months), .months(1)):
            return String(
                localized: "\(introPrice) billed today for your first \(months) months, then \(fullPrice)/month. Cancel anytime in App Store settings.",
                comment: "One-time offer, under the button. First %@: the discounted price charged today. %lld: months the discount lasts, 2 or more. Second %@: the regular monthly price."
            )

        // A renewal period this app does not sell.
        default:
            return L10n.withTechnicalDetail(
                english: "\(introPrice) billed today for your first \(englishPhrase(first)), then \(fullPrice)/\(englishPhrase(renewal)). Cancel anytime in App Store settings.",
                translated: String(
                    localized: "\(introPrice) billed today, then \(fullPrice) at each renewal. Cancel anytime in App Store settings.",
                    comment: "One-time offer, under the button, for an unusual billing period. First %@: the discounted price charged today. Second %@: the regular price charged at each renewal."
                )
            )
        }
    }

    /// "year", "2 years", "month", "6 months". English only, and only for
    /// the unsold-period case above.
    private static func englishPhrase(_ duration: Duration) -> String {
        switch duration {
        case .years(1):          return "year"
        case .years(let years):  return "\(years) years"
        case .months(1):         return "month"
        case .months(let months): return "\(months) months"
        }
    }
}
