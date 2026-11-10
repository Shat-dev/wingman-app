//
//  SessionErrorClassifierTests.swift
//  WingmanTests
//
//  WP3 of the localization plan: the keep-session-or-sign-out decision after
//  a failed session refresh must not depend on the language of an error's
//  display text.
//
//  The plan's test for this: feed the known error types and get the same
//  sign-out decisions as today, with the language set to German. The
//  original decision logic is copied here as the reference, and every case
//  is checked against it.
//

import XCTest
import Auth
@testable import Wingman

@MainActor
final class SessionErrorClassifierTests: XCTestCase {

    private typealias Decision = SessionErrorClassifier.Decision
    private typealias Facts = SessionErrorClassifier.Facts

    // MARK: - The original logic, kept as the reference

    private func originalIsNetworkError(domain: String, code: Int, description: String) -> Bool {
        if domain == NSURLErrorDomain {
            let networkErrorCodes: [Int] = [
                NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost, NSURLErrorTimedOut,
                NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed,
                NSURLErrorDataNotAllowed, NSURLErrorInternationalRoamingOff
            ]
            return networkErrorCodes.contains(code)
        }
        let errorDescription = description.lowercased()
        let networkKeywords = ["network", "internet", "offline", "connection", "timeout", "unreachable"]
        return networkKeywords.contains { errorDescription.contains($0) }
    }

    private func originalIsAuthenticationError(description: String) -> Bool {
        let errorDescription = description.lowercased()
        let authKeywords = ["unauthorized", "401", "invalid", "expired", "token", "authentication", "forbidden", "403"]
        return authKeywords.contains { errorDescription.contains($0) }
    }

    /// True when the original code would have signed the user out.
    private func originalSignsOut(_ facts: Facts) -> Bool {
        if originalIsNetworkError(domain: facts.domain, code: facts.code, description: facts.description)
            || facts.description.contains("Timeout") {
            return false
        }
        return originalIsAuthenticationError(description: facts.description)
    }

    private func signsOut(_ facts: Facts, english: Bool) -> Bool {
        SessionErrorClassifier.decision(for: facts, usesEnglishDescriptions: english) == .signOut
    }

    // MARK: - Cases

    /// A Supabase auth error as it reaches the classifier: its display text
    /// is the server's message.
    private func auth(_ message: String) -> Facts {
        Facts(domain: "Auth.AuthError", code: 0, authMessage: message, description: message)
    }

    private func url(_ code: Int, _ description: String = "The operation couldn’t be completed.") -> Facts {
        Facts(domain: NSURLErrorDomain, code: code, description: description)
    }

    private var authCases: [(String, Facts)] {
        [
            ("refresh token not found", auth("Invalid Refresh Token: Refresh Token Not Found")),
            ("refresh token already used", auth("Invalid Refresh Token: Already Used")),
            ("session expired", auth("Invalid Refresh Token: Session Expired")),
            ("session expired (inactivity)", auth("Session Expired (Inactivity)")),
            ("bad JWT", auth("invalid JWT: unable to parse or verify signature, token is expired")),
            ("no authorization", auth("This endpoint requires a Bearer token")),
            ("session missing", auth("Auth session missing.")),
            ("session not found", auth("Session from session_id claim in JWT does not exist")),
            ("user not found", auth("User from sub claim in JWT does not exist")),
            ("user banned", auth("User is banned")),
            ("rate limited", auth("Request rate limit reached")),
            ("server error", auth("Unexpected failure, please check server logs for more information")),
            ("hook timeout", auth("Failed to reach hook within maximum time of 5.000000 seconds")),
            ("gateway timeout", auth("upstream request timeout")),
            ("db connection", auth("Database error: connection refused")),
            ("malformed JWT", auth("A malformed JWT received."))
        ]
    }

    private var typedCases: [(String, Facts)] {
        var cases: [(String, Facts)] = [
            ("the app's own timeout", Facts(SessionErrorClassifier.timeoutError())),
            ("cancelled task", Facts(CancellationError())),
            ("posix network down", Facts(domain: NSPOSIXErrorDomain, code: Int(ENETDOWN), description: "Network is down")),
            ("posix timed out", Facts(domain: NSPOSIXErrorDomain, code: Int(ETIMEDOUT), description: "Operation timed out")),
            ("posix connection refused", Facts(domain: NSPOSIXErrorDomain, code: Int(ECONNREFUSED), description: "Connection refused")),
            ("posix connection reset", Facts(domain: NSPOSIXErrorDomain, code: Int(ECONNRESET), description: "Connection reset by peer"))
        ]
        for code in SessionErrorClassifier.urlNetworkCodes.sorted() {
            cases.append(("url network \(code)", Facts(URLError(URLError.Code(rawValue: code)))))
        }
        return cases
    }

    /// Errors with no type the classifier knows, described in English as
    /// the system would in an English app.
    private var untypedEnglishCases: [(String, Facts)] {
        [
            ("url cancelled", Facts(URLError(.cancelled))),
            ("url bad server response", Facts(URLError(.badServerResponse))),
            ("url auth required", url(NSURLErrorUserAuthenticationRequired, "Authentication is required to access this resource.")),
            ("url with network words", url(NSURLErrorBadURL, "The network connection is offline")),
            ("decoding", Facts(domain: NSCocoaErrorDomain, code: 4864, description: "The data couldn’t be read because it isn’t in the correct format.")),
            ("generic invalid", Facts(domain: "Other", code: 1, description: "The request is invalid")),
            ("generic token", Facts(domain: "Other", code: 2, description: "Token could not be read")),
            ("generic 401", Facts(domain: "Other", code: 3, description: "Server returned 401")),
            ("generic offline", Facts(domain: "Other", code: 4, description: "The Internet connection appears to be offline.")),
            ("generic Timeout", Facts(domain: "Other", code: 5, description: "Timeout")),
            ("generic nothing", Facts(domain: "Other", code: 6, description: "Something went wrong"))
        ]
    }

    // MARK: - English: every decision equals the original

    func testEnglishDecisionsEqualTheOriginalForEveryCase() {
        let all = authCases + typedCases + untypedEnglishCases
        XCTAssertGreaterThanOrEqual(all.count, 40)
        for (name, facts) in all {
            XCTAssertEqual(signsOut(facts, english: true), originalSignsOut(facts), name)
        }
    }

    // MARK: - Another language: same decisions for everything typed

    /// The plan's test. Auth errors carry the server's English message in
    /// any language, and typed failures are decided by code.
    func testATranslatedAppMakesTheSameDecisionsForKnownErrorTypes() {
        for (name, facts) in authCases + typedCases {
            XCTAssertEqual(signsOut(facts, english: false), originalSignsOut(facts), name)
            XCTAssertEqual(
                SessionErrorClassifier.decision(for: facts, usesEnglishDescriptions: false),
                SessionErrorClassifier.decision(for: facts, usesEnglishDescriptions: true),
                name
            )
        }
    }

    /// The same network failures described in German: the code decides, the
    /// words are never read.
    func testNetworkFailuresAreRecognisedWhateverTheirDescriptionSays() {
        let german: [Facts] = [
            url(NSURLErrorNotConnectedToInternet, "Es besteht anscheinend keine Verbindung zum Internet."),
            url(NSURLErrorTimedOut, "Zeitüberschreitung bei der Anforderung."),
            url(NSURLErrorCannotFindHost, "Ein Server mit dem angegebenen Hostnamen wurde nicht gefunden."),
            Facts(domain: NSPOSIXErrorDomain, code: Int(ENETUNREACH), description: "Das Netzwerk ist nicht erreichbar")
        ]
        for facts in german {
            XCTAssertEqual(
                SessionErrorClassifier.decision(for: facts, usesEnglishDescriptions: false), .keepSession(.network), facts.description
            )
        }
    }

    /// An error of no known type in a translated app never signs anyone
    /// out, whatever words its description happens to contain.
    func testATranslatedAppNeverSignsOutOnAnUnrecognisedError() {
        let descriptions = [
            "Das Token ist ungültig", "Token could not be read", "Server returned 401",
            "Authentication failed", "invalid", "Etwas ist schiefgelaufen"
        ]
        for description in descriptions {
            let facts = Facts(domain: "Other", code: 1, description: description)
            XCTAssertEqual(
                SessionErrorClassifier.decision(for: facts, usesEnglishDescriptions: false),
                .keepSession(.unrecognised), description
            )
        }
    }

    // MARK: - The decisions themselves

    func testWhatSignsOutAndWhatDoesNot() {
        let signOut = ["refresh token not found", "refresh token already used", "session expired", "bad JWT", "no authorization"]
        let keep = ["session missing", "session not found", "user not found", "rate limited", "server error", "hook timeout", "db connection"]
        let byName = Dictionary(uniqueKeysWithValues: authCases)
        for name in signOut {
            XCTAssertTrue(signsOut(byName[name]!, english: true), name)
        }
        for name in keep {
            XCTAssertFalse(signsOut(byName[name]!, english: true), name)
        }
    }

    func testReasonsForKeepingTheSession() {
        XCTAssertEqual(SessionErrorClassifier.decision(for: SessionErrorClassifier.timeoutError()), .keepSession(.timeout))
        XCTAssertEqual(SessionErrorClassifier.decision(for: URLError(.notConnectedToInternet)), .keepSession(.network))
        XCTAssertEqual(SessionErrorClassifier.decision(for: CancellationError()), .keepSession(.cancelled))
    }

    // MARK: - Real error values

    func testTheTimeoutErrorKeepsItsShape() {
        let error = SessionErrorClassifier.timeoutError()
        XCTAssertEqual(error.domain, "SessionValidation")
        XCTAssertEqual(error.code, -1)
        XCTAssertEqual(error.localizedDescription, "Timeout")
    }

    /// A real Supabase error: the facts carry the server's message, and the
    /// display text is that same message.
    func testFactsFromARealAuthError() throws {
        let response = try XCTUnwrap(HTTPURLResponse(
            url: try XCTUnwrap(URL(string: "https://example.supabase.co/auth/v1/token")),
            statusCode: 400, httpVersion: nil, headerFields: nil
        ))
        let error = AuthError.api(
            message: "Invalid Refresh Token: Already Used", errorCode: .refreshTokenAlreadyUsed,
            underlyingData: Data(), underlyingResponse: response
        )
        let facts = Facts(error)
        XCTAssertEqual(facts.authMessage, "Invalid Refresh Token: Already Used")
        XCTAssertEqual(facts.description, "Invalid Refresh Token: Already Used")
        XCTAssertEqual(SessionErrorClassifier.decision(for: error, usesEnglishDescriptions: false), .signOut)
        XCTAssertEqual(SessionErrorClassifier.decision(for: error, usesEnglishDescriptions: true), .signOut)

        let missing = Facts(AuthError.sessionMissing)
        XCTAssertEqual(missing.authMessage, "Auth session missing.")
        XCTAssertEqual(SessionErrorClassifier.decision(for: AuthError.sessionMissing, usesEnglishDescriptions: false), .keepSession(.unrecognised))
    }

    func testFactsFromSystemErrors() {
        let offline = Facts(URLError(.notConnectedToInternet))
        XCTAssertEqual(offline.domain, NSURLErrorDomain)
        XCTAssertEqual(offline.code, NSURLErrorNotConnectedToInternet)
        XCTAssertNil(offline.authMessage)
        XCTAssertFalse(offline.isCancellation)
        XCTAssertTrue(Facts(CancellationError()).isCancellation)
    }
}
