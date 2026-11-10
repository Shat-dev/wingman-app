//
//  SessionErrorClassifier.swift
//  Wingman
//
//  What to do when refreshing the session fails at launch: keep the cached
//  session, or sign the user out.
//
//  Signing out wrongly throws a working user back to the login screen, so
//  the rule has always been: sign out only on a real authentication error;
//  keep the session for anything that looks like a network problem, a
//  timeout, or something unrecognised.
//
//  THE PROBLEM THIS FILE FIXES
//
//  The decision used to be made by searching `error.localizedDescription`
//  for English words ("network", "timeout", "invalid", "expired", "token"…).
//  `localizedDescription` is text meant for display. For system errors it is
//  written in the app's language, so in a German app the same failure reads
//  differently and the search answers differently. Logic must not depend on
//  what a message happens to say in one language.
//
//  HOW IT DECIDES NOW
//
//    1. By type, in any language:
//         - the app's own five-second timeout (its error domain and code);
//         - network failures (URL loading and POSIX socket error codes);
//         - a cancelled task.
//       All three keep the session.
//    2. A Supabase auth error is judged by the SERVER's message. That text
//       comes from the auth server (or the SDK) and is English whatever
//       language the app runs in, so reading it is not reading localized
//       text. The same words are looked for as before, so every decision
//       made for these errors today is unchanged.
//    3. Anything else:
//         - English app: the original word search on the description, kept
//           exactly as it was, so English behaviour cannot change.
//         - Translated app: keep the session. An unrecognised error in an
//           unknown language is never a reason to sign someone out.
//
//  The plan asked for a few days of production logging of which errors
//  really arrive here before removing the word search. That has not been
//  done, which is why rule 3 keeps the search for English instead of
//  deleting it.
//

import Foundation
import Auth

nonisolated enum SessionErrorClassifier {

    enum Decision: Equatable {
        case keepSession(Reason)
        case signOut

        enum Reason: Equatable {
            case timeout
            case network
            case cancelled
            case unrecognised
        }
    }

    // MARK: - The app's own timeout

    static let timeoutDomain = "SessionValidation"
    static let timeoutCode = -1

    /// The error the five-second validation timeout throws. Its description
    /// stays "Timeout", as before; nothing reads it any more.
    static func timeoutError() -> NSError {
        NSError(domain: timeoutDomain, code: timeoutCode, userInfo: [NSLocalizedDescriptionKey: "Timeout"])
    }

    // MARK: - What is known about an error

    /// The parts of an error the decision is made from.
    struct Facts: Equatable {
        var domain: String
        var code: Int
        var isCancellation: Bool
        /// The server's (English) message when this is a Supabase auth
        /// error; nil for every other kind of error.
        var authMessage: String?
        /// Display text. Only consulted in an English app, as the last step.
        var description: String

        init(domain: String, code: Int, isCancellation: Bool = false, authMessage: String? = nil, description: String) {
            self.domain = domain
            self.code = code
            self.isCancellation = isCancellation
            self.authMessage = authMessage
            self.description = description
        }

        init(_ error: Error) {
            let nsError = error as NSError
            domain = nsError.domain
            code = nsError.code
            isCancellation = error is CancellationError
            authMessage = (error as? AuthError)?.message
            description = error.localizedDescription
        }
    }

    // MARK: - Deciding

    static func decision(for error: Error, usesEnglishDescriptions: Bool = L10n.isSourceLanguage) -> Decision {
        decision(for: Facts(error), usesEnglishDescriptions: usesEnglishDescriptions)
    }

    static func decision(for facts: Facts, usesEnglishDescriptions: Bool) -> Decision {
        // 1. By type.
        if facts.domain == timeoutDomain, facts.code == timeoutCode {
            return .keepSession(.timeout)
        }
        if isNetworkFailure(domain: facts.domain, code: facts.code) {
            return .keepSession(.network)
        }
        if facts.isCancellation {
            return .keepSession(.cancelled)
        }

        // 2. A Supabase auth error, by the server's own English message.
        if let message = facts.authMessage {
            return decisionFromEnglishText(message, domain: facts.domain)
        }

        // 3. Anything else.
        guard usesEnglishDescriptions else { return .keepSession(.unrecognised) }
        return decisionFromEnglishText(facts.description, domain: facts.domain)
    }

    // MARK: - Network failures by code

    static let urlNetworkCodes: Set<Int> = [
        NSURLErrorNotConnectedToInternet,
        NSURLErrorNetworkConnectionLost,
        NSURLErrorTimedOut,
        NSURLErrorCannotConnectToHost,
        NSURLErrorCannotFindHost,
        NSURLErrorDNSLookupFailed,
        NSURLErrorDataNotAllowed,
        NSURLErrorInternationalRoamingOff
    ]

    /// Socket-level failures that reach the app without a URL error around
    /// them: network down, unreachable, reset, timed out, refused, no route.
    static let posixNetworkCodes: Set<Int> = [
        Int(ENETDOWN), Int(ENETUNREACH), Int(ECONNRESET), Int(ETIMEDOUT), Int(ECONNREFUSED), Int(EHOSTUNREACH)
    ]

    static func isNetworkFailure(domain: String, code: Int) -> Bool {
        if domain == NSURLErrorDomain { return urlNetworkCodes.contains(code) }
        if domain == NSPOSIXErrorDomain { return posixNetworkCodes.contains(code) }
        return false
    }

    // MARK: - The original word search

    static let networkWords = ["network", "internet", "offline", "connection", "timeout", "unreachable"]
    static let authWords = ["unauthorized", "401", "invalid", "expired", "token", "authentication", "forbidden", "403"]

    /// The decision exactly as the original code made it from a piece of
    /// English text: network words or "Timeout" keep the session, then
    /// authentication words sign out, and anything else keeps it.
    ///
    /// One detail is preserved on purpose: for a URL-loading error the
    /// original never searched for network words (its code alone decided
    /// that), so neither does this.
    static func decisionFromEnglishText(_ text: String, domain: String) -> Decision {
        let lowercased = text.lowercased()

        let mentionsNetwork = domain != NSURLErrorDomain && networkWords.contains { lowercased.contains($0) }
        if mentionsNetwork || text.contains("Timeout") {
            return .keepSession(.network)
        }
        if authWords.contains(where: { lowercased.contains($0) }) {
            return .signOut
        }
        return .keepSession(.unrecognised)
    }
}
