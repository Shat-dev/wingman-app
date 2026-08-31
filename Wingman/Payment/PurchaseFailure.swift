//
//  PurchaseFailure.swift
//  Wingman
//

import Foundation
import RevenueCat

/// How the purchase alert should present itself.
///
/// Exists because one outcome on this path isn't a failure at all: a deferred
/// payment is waiting on an approval, and titling that "Error" with an error
/// haptic tells the user something broke when nothing did.
///
/// `.error` is the default everywhere, so every call site that predates this
/// type — a dozen `error = "…"; showAlert = true` pairs across both purchase
/// screens — keeps the exact alert it already had.
enum PurchaseAlertKind {

    case error
    case info

    var title: String {
        switch self {
        case .error: return "Error"
        case .info: return "Waiting for approval"
        }
    }

    /// Fired when the alert appears. `.info` gets a plain tap: the notification
    /// haptics all carry a verdict (`error`, `warning`, `success`) and none of
    /// them is true here — nothing failed, and nothing has succeeded yet.
    @MainActor
    func playHaptic() {
        switch self {
        case .error: HapticManager.shared.error()
        case .info: HapticManager.shared.tap()
        }
    }
}

/// The three things every purchase call site needs from a thrown RevenueCat
/// error: the sentence shown to the user, how that sentence should be
/// presented, and the `failure_reason` bucket sent to PostHog.
///
/// Extracted because the two purchase paths had drifted into different
/// answers for the same error. `PaywallViewModel.purchase(_:)` hand-numbered
/// three codes and got one wrong — its `case 4` was commented "Payment
/// pending", but RevenueCat's 4 is `purchaseInvalidError` and pending is 20,
/// so a deferred purchase (Ask to Buy, or a bank approval step) fell through
/// to "Purchase failed. Please try again." That is the opposite of the truth:
/// nothing failed, the payment is parked awaiting someone's approval, and
/// retrying cannot help. `SecondChanceOfferViewModel.purchase(_:)` mapped
/// nothing at all and showed that same line for every code.
///
/// Codes are matched through RevenueCat's own `ErrorCode` enum rather than
/// integer literals, so this can't silently drift out of numbering again.
struct PurchaseFailure {

    /// Shown in the purchase alert.
    let message: String

    /// `failure_reason` on `paywall_purchase_failed` /
    /// `recovery_offer_purchase_failed`. Buckets the raw `error_code` that
    /// ships alongside it, so a breakdown separates "the store broke" from
    /// "this needs approval" without needing the numbers memorized.
    let reason: String

    /// How to present `message`. Defaults to `.error` and stays there for
    /// every branch below except the deferred-payment one, so nothing that
    /// currently reads as an error stops doing so.
    private(set) var alertKind: PurchaseAlertKind = .error

    /// Maps a thrown purchase error. Non-RevenueCat errors keep the generic
    /// bucket: the domain check matters because these buckets key off small
    /// integers, and an unrelated `NSError` that happens to carry code 20
    /// would otherwise be reported as a pending payment.
    init(_ error: Error) {
        let nsError = error as NSError

        guard nsError.domain == "RevenueCat.ErrorCode",
              let code = ErrorCode(rawValue: nsError.code) else {
            self.message = Self.genericMessage
            self.reason = Self.genericReason
            return
        }

        switch code {
        case .paymentPendingError:
            // Deferred, not failed: StoreKit is waiting on an approval the
            // buyer can't give themselves (Ask to Buy on a family account, or
            // an SCA step at the bank). RevenueCat's delegate delivers the
            // entitlement whenever approval lands, so the copy promises that
            // rather than sending them back to tap Subscribe again.
            self.message = "This purchase needs approval before it can go through — usually from the account holder or your bank. You'll get access automatically once it's approved."
            self.reason = "payment_pending"
            self.alertKind = .info

        case .storeProblemError:
            self.message = "The App Store is having trouble right now. Please try again in a few minutes."
            self.reason = "store_problem"

        case .purchaseNotAllowedError:
            self.message = "Purchases aren't allowed on this device. Check Screen Time restrictions and try again."
            self.reason = "not_allowed"

        case .purchaseInvalidError:
            self.message = "That payment method was declined. Check your payment details in the App Store and try again."
            self.reason = "payment_invalid"

        case .productNotAvailableForPurchaseError:
            self.message = "This plan isn't available on your App Store account right now."
            self.reason = "product_unavailable"

        case .productAlreadyPurchasedError, .receiptAlreadyInUseError:
            // They own it already — Restore is on both purchase screens, and
            // it's the only action that actually resolves this.
            self.message = "You already have a subscription on this account. Tap Restore to get access back."
            self.reason = "already_purchased"

        case .networkError, .offlineConnectionError:
            self.message = "You appear to be offline. Reconnect and try again."
            self.reason = "network"

        case .unexpectedBackendResponseError, .unknownBackendError:
            self.message = "Something went wrong on our end. Please try again."
            self.reason = "backend"

        case .configurationError, .invalidCredentialsError, .invalidAppleSubscriptionKeyError:
            // Ours to fix, not theirs to retry — the bucket is what makes it
            // visible, since the user-facing wording can only ever be vague.
            self.message = "Purchases are temporarily unavailable. Please try again later."
            self.reason = "configuration"

        default:
            self.message = Self.genericMessage
            self.reason = Self.genericReason
        }
    }

    private static let genericMessage = "Purchase failed. Please try again."

    /// Kept as the fallback bucket's name so existing breakdowns don't lose
    /// their series — after this change it means "unmapped", not "everything".
    private static let genericReason = "store_error"
}
