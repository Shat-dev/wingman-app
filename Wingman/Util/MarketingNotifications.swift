//
//  MarketingNotifications.swift
//  Wingman
//
//  Three local reminders for people who closed the onboarding paywall without
//  subscribing: +1, +3 and +7 days after it closed.
//
//  Local, not server push, on purpose: the device is the thing that knows the
//  subscription state (RevenueCat → `AuthManager.hasActiveSubscription`), and
//  scheduling here costs no network call. Two gates keep them to
//  non-subscribers:
//    - ARM: only from the onboarding paywall's close-without-purchase X, and
//      only if not premium / not opted out / never armed / already authorised.
//    - CANCEL: RootView cancels everything whenever `hasActiveSubscription` is
//      true, on appear and on change, so a purchase made anywhere (onboarding,
//      a feature gate, the one-time offer, a restore, another device) clears
//      them.
//
//  Copy is a question, never an instruction: no prices, no trial lengths, no
//  promised outcomes. Each day is written from one onboarding answer (the same
//  `onboarding_<key>` values PaywallCopy reads). The first pick of a
//  multi-select answer is the one that counts. Anything unrecognised, skipped,
//  "Other" or from an older build falls back to a line that fits everyone, so
//  renaming an option in OnboardingFlow degrades to the fallback, not to a
//  broken notification. Bodies are kept discreet because they show on the lock
//  screen.
//
//  App Review 4.5.4: the consent line on the onboarding loading screen and the
//  "Tips & offers" switch in Settings are what make these allowed.
//

import Foundation
import UserNotifications
import Combine

nonisolated enum MarketingNotifications {

    // MARK: - Schedule

    private struct Reminder {
        let id: String
        let days: Int
    }

    private static let schedule: [Reminder] = [
        Reminder(id: "day1", days: 1),
        Reminder(id: "day3", days: 3),
        Reminder(id: "day7", days: 7),
    ]

    private static let identifierPrefix = "marketing."
    private static let kindValue = "marketing"

    private static var identifiers: [String] {
        schedule.map { identifierPrefix + $0.id }
    }

    // MARK: - Stored flags

    private static let optedOutKey = "marketing.optedOut"
    private static let armedKey = "marketing.armed"

    /// The user's "Tips & offers" switch, inverted. Setting it to true cancels
    /// anything already scheduled or delivered.
    static var isOptedOut: Bool {
        get { UserDefaults.standard.bool(forKey: optedOutKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: optedOutKey)
            if newValue { cancelAll() }
        }
    }

    // MARK: - Arm

    /// Schedules all three reminders when every condition holds:
    ///   1. not premium
    ///   2. not opted out
    ///   3. never armed before on this install (relaunching never re-arms)
    ///   4. notifications already authorised. Never prompts from here.
    static func armIfEligible(isPremium: Bool) async {
        let defaults = UserDefaults.standard
        guard !isPremium else { return log("🔕 Marketing: not armed (premium)") }
        guard !isOptedOut else { return log("🔕 Marketing: not armed (opted out)") }
        guard !defaults.bool(forKey: armedKey) else { return log("🔕 Marketing: not armed (already armed once)") }

        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .authorized, .provisional, .ephemeral:
            break
        default:
            return log("🔕 Marketing: not armed (authorization \(status.rawValue))")
        }

        // Set before scheduling: a crash halfway through must not let a later
        // launch arm a second, duplicate set.
        defaults.set(true, forKey: armedKey)

        let bodies = personalisedBodies()
        for reminder in schedule {
            let content = UNMutableNotificationContent()
            content.title = "Wingman"
            content.body = bodies[reminder.id] ?? ""
            content.sound = .default
            content.userInfo = ["kind": kindValue, "id": reminder.id]

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: TimeInterval(reminder.days * 24 * 60 * 60),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: identifierPrefix + reminder.id,
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
            } catch {
                log("❌ Marketing: failed to schedule \(reminder.id): \(error)")
            }
        }
        log("🔔 Marketing: armed \(schedule.count) reminders")
        await debugLogPending("after arm")
    }

    // MARK: - Cancel

    /// Removes pending and delivered reminders. Cheap; safe to call repeatedly.
    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
        #if DEBUG
        Task { await debugLogPending("after cancelAll") }
        #endif
    }

    /// Debug builds only: prints what `getPendingNotificationRequests` holds
    /// for these reminders, so scheduling can be checked from the console.
    static func debugLogPending(_ context: String) async {
        #if DEBUG
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
            .filter { $0.identifier.hasPrefix(identifierPrefix) }
        let lines = pending.map { request -> String in
            let seconds = (request.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval ?? 0
            return "\(request.identifier) +\(Int(seconds / 86_400))d \"\(request.content.body)\""
        }
        log("🔎 Marketing pending (\(context)): \(pending.count) \(lines)")
        #endif
    }

    // MARK: - Tap

    /// The reminder id ("day1", …) when `userInfo` came from one of these.
    static func id(from userInfo: [AnyHashable: Any]) -> String? {
        guard userInfo["kind"] as? String == kindValue else { return nil }
        return userInfo["id"] as? String
    }

    // MARK: - Copy

    private static func personalisedBodies() -> [String: String] {
        let defaults = UserDefaults.standard
        func firstPick(_ key: String) -> String? {
            defaults.string(forKey: "onboarding_\(key)")?
                .components(separatedBy: ", ")
                .first
        }
        return [
            "day1": motivationLine(firstPick("motivation")),
            "day3": barrierLine(firstPick("barriers")),
            "day7": goalLine(firstPick("goals")),
        ]
    }

    /// Day 1, from "What brought you to Wingman?"
    static func motivationLine(_ answer: String?) -> String {
        switch answer {
        case "Back on the market after a breakup or divorce":
            return "What would your first conversation back out there sound like?"
        case "I freeze up around women I find attractive":
            return "What happens in the second before you freeze?"
        case "Done with dating apps":
            return "When did you last meet someone without a screen in between?"
        case "Tired of being on my own":
            return "Who did you notice today that you didn\u{2019}t talk to?"
        case "Want more confidence in general":
            return "Where in your day could you say one more hello?"
        default:
            return "When did you last start a conversation with a stranger?"
        }
    }

    /// Day 3, from "What usually stops you from doing so?"
    /// ("embarrased" matches the stored option text, misspelling included.)
    static func barrierLine(_ answer: String?) -> String {
        switch answer {
        case "Fear of rejection or being embarrased":
            return "What\u{2019}s the worst a polite \u{201C}no\u{201D} could actually cost you?"
        case "Fear of social consequences":
            return "Would anyone around you really remember you saying hi?"
        case "Not knowing what to say or how to start":
            return "What if your opener didn\u{2019}t need to be clever?"
        case "Worrying about coming across wrong":
            return "What if a little nervousness just reads as genuine?"
        default:
            return "What\u{2019}s the one thing that stops you from saying hi?"
        }
    }

    /// Day 7, from "What are you mainly hoping to improve?"
    static func goalLine(_ answer: String?) -> String {
        switch answer {
        case "Better mindset & confidence":
            return "What would feeling sure of yourself change this week?"
        case "Keeping conversations going":
            return "What\u{2019}s one question you could ask that isn\u{2019}t small talk?"
        case "Creating attraction and romantic interest":
            return "When did a conversation last feel like more than small talk?"
        default: // includes "Learning how to approach"
            return "Who would you talk to this week if nerves weren\u{2019}t a factor?"
        }
    }
}

// MARK: - Tap routing

/// Carries a reminder tap from the notification delegate to MainTabView.
/// A flag rather than a callback so a cold-launch tap survives splash and
/// RootView's routing: MainTabView reads it on appear as well as on change.
@MainActor
final class NotificationRouter: ObservableObject {
    static let shared = NotificationRouter()
    @Published var openScenarios = false
    private init() {}
}

// MARK: - Delegate

/// Set as `UNUserNotificationCenter.current().delegate` at launch. Shows
/// notifications while the app is open, and routes reminder taps.
final class AppNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AppNotificationDelegate()

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier,
              let id = MarketingNotifications.id(from: response.notification.request.content.userInfo)
        else { return }
        await MainActor.run {
            log("🔔 Marketing: opened \(id)")
            Analytics.capture(Analytics.Event.marketingNotificationOpened, ["id": id])
            NotificationRouter.shared.openScenarios = true
        }
    }
}
