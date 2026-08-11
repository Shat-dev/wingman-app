//
//  HapticManager.swift
//  Wingman
//
//  The single place the app talks to the Taptic Engine. Call sites ask for a
//  *meaning* (`tap`, `success`, `threshold`) and never pick a UIKit feedback
//  style themselves, so the physical vocabulary can be retuned here without
//  touching a screen.
//
//  House rules for callers:
//    - For an async action the result haptic (`success`/`warning`/`error`) is
//      the only haptic — don't also fire a `tap` on the press.
//    - Gesture haptics fire once, on threshold crossing (`threshold`), never
//      continuously while the finger moves.
//    - Anything fired from a Timer or a background callback hops to the main
//      actor first; this type is main-actor isolated.
//

import UIKit

@MainActor
final class HapticManager {

    static let shared = HapticManager()

    // MARK: - App-level enable flag
    //
    // The OS already honours the system haptics setting, so this exists only
    // as an in-app override (Settings toggle, tests, previews). Defaults to
    // on — `bool(forKey:)` returning false for an unset key is why the stored
    // value is inverted into a "disabled" key rather than an "enabled" one.
    private static let disabledDefaultsKey = "haptics_disabled"

    var isEnabled: Bool {
        get { !UserDefaults.standard.bool(forKey: Self.disabledDefaultsKey) }
        set { UserDefaults.standard.set(!newValue, forKey: Self.disabledDefaultsKey) }
    }

    // MARK: - Generator cache
    //
    // Generators are created on first use and `prepare()`d immediately, then
    // re-prepared right after every fire. The re-prepare is what keeps the
    // engine warm: without it the first haptic after an idle gap arrives a
    // frame or two late, which is audible as a broken rhythm in anything
    // repeating (the onboarding tick loop, for one).
    private var selectionGenerator: UISelectionFeedbackGenerator?
    private var notificationGenerator: UINotificationFeedbackGenerator?
    private var impactGenerators: [Int: UIImpactFeedbackGenerator] = [:]

    // MARK: - Debounce
    //
    // Identical events inside this window collapse to one, which absorbs
    // double-fires from a fast double-tap or a view re-render. Deliberately
    // short: the onboarding tick loop runs at 0.2s, five times this window,
    // so no tick is ever swallowed. Keyed per event, so two *different*
    // haptics from one gesture both still fire.
    private var lastFireTimes: [String: TimeInterval] = [:]
    private let debounceInterval: TimeInterval = 0.04

    private init() {}

    // MARK: - Semantic API

    /// Light acknowledgement — buttons, tab switches, sheet dismissals.
    func tap() {
        fireImpact(.light, key: "tap")
    }

    /// Weightier acknowledgement for primary CTAs — submit, start, continue.
    func tapStrong() {
        fireImpact(.medium, key: "tapStrong")
    }

    /// Picker-detent tick — option picks, toggles, segmented changes, and any
    /// continuous "work is happening" texture. The lightest thing available,
    /// so it doesn't fatigue when repeated.
    func selection() {
        guard shouldFire(key: "selection") else { return }
        let generator = selectionGenerator ?? makeSelectionGenerator()
        generator.selectionChanged()
        generator.prepare()
    }

    /// A milestone landed — practice/lesson/game complete, approach logged,
    /// an onboarding step locking in.
    func success() {
        fireNotification(.success, key: "success")
    }

    /// Something didn't land, without punishing the user — wrong answer.
    func warning() {
        fireNotification(.warning, key: "warning")
    }

    /// A failure the user has to deal with — save failed, network error.
    func error() {
        fireNotification(.error, key: "error")
    }

    /// Confirming something irreversible — delete account, reset progress.
    func destructive() {
        fireImpact(.heavy, key: "destructive")
    }

    /// A drag or swipe crossing its commit threshold. Fires once at the
    /// crossing, never per movement.
    func threshold() {
        fireImpact(.rigid, key: "threshold")
    }

    // MARK: - Firing

    private func fireImpact(_ style: UIImpactFeedbackGenerator.FeedbackStyle, key: String) {
        guard shouldFire(key: key) else { return }
        let generator = impactGenerator(for: style)
        generator.impactOccurred()
        generator.prepare()
    }

    private func fireNotification(_ type: UINotificationFeedbackGenerator.FeedbackType, key: String) {
        guard shouldFire(key: key) else { return }
        let generator = notificationGenerator ?? makeNotificationGenerator()
        generator.notificationOccurred(type)
        generator.prepare()
    }

    // MARK: - Lazy generators

    private func makeSelectionGenerator() -> UISelectionFeedbackGenerator {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        selectionGenerator = generator
        return generator
    }

    private func makeNotificationGenerator() -> UINotificationFeedbackGenerator {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        notificationGenerator = generator
        return generator
    }

    private func impactGenerator(for style: UIImpactFeedbackGenerator.FeedbackStyle) -> UIImpactFeedbackGenerator {
        if let cached = impactGenerators[style.rawValue] { return cached }
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        impactGenerators[style.rawValue] = generator
        return generator
    }

    // MARK: - Debounce helper

    private func shouldFire(key: String) -> Bool {
        guard isEnabled else { return false }

        let now = CACurrentMediaTime()
        if let last = lastFireTimes[key], now - last < debounceInterval {
            return false
        }
        lastFireTimes[key] = now
        return true
    }
}
