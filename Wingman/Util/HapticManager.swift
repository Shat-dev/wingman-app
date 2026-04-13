//
//  HapticManager.swift
//  Wingman
//

import UIKit

@MainActor
final class HapticManager {

    static let shared = HapticManager()

    // MARK: - Generators (pre-initialized)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()

    // MARK: - Debounce
    private var lastFireTimes: [String: TimeInterval] = [:]
    private let debounceInterval: TimeInterval = 0.1

    private init() {
        // Prepare generators for first use
        selectionGenerator.prepare()
        lightImpactGenerator.prepare()
        mediumImpactGenerator.prepare()
        notificationGenerator.prepare()
    }

    // MARK: - Debounce Helper
    private func shouldFire(key: String) -> Bool {
        let now = CACurrentMediaTime()
        if let last = lastFireTimes[key], now - last < debounceInterval {
            return false
        }
        lastFireTimes[key] = now
        return true
    }

    // MARK: - Selection (lightest — option picks, toggles, radio buttons)
    func selection() {
        guard shouldFire(key: "selection") else { return }
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()
    }

    // MARK: - Light Impact (tab switches, secondary actions)
    func lightImpact() {
        guard shouldFire(key: "lightImpact") else { return }
        lightImpactGenerator.impactOccurred()
        lightImpactGenerator.prepare()
    }

    // MARK: - Medium Impact (primary CTAs — submit, start, continue, save)
    func mediumImpact() {
        guard shouldFire(key: "mediumImpact") else { return }
        mediumImpactGenerator.impactOccurred()
        mediumImpactGenerator.prepare()
    }

    // MARK: - Heavy Impact (streak milestones, unlocks)
    func heavyImpact() {
        guard shouldFire(key: "heavyImpact") else { return }
        heavyImpactGenerator.impactOccurred()
        heavyImpactGenerator.prepare()
    }

    // MARK: - Success (completions — daily practice, lesson, game, approach log)
    func success() {
        guard shouldFire(key: "success") else { return }
        notificationGenerator.notificationOccurred(.success)
        notificationGenerator.prepare()
    }

    // MARK: - Warning (incorrect answer — encouraging, not punishing)
    func warning() {
        guard shouldFire(key: "warning") else { return }
        notificationGenerator.notificationOccurred(.warning)
        notificationGenerator.prepare()
    }

    // MARK: - Error (save failures, network errors)
    func error() {
        guard shouldFire(key: "error") else { return }
        notificationGenerator.notificationOccurred(.error)
        notificationGenerator.prepare()
    }
}
