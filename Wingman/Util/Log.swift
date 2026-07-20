//
//  Log.swift
//  Wingman
//
//  Logging shim. Signature-compatible with `Swift.print` so every existing
//  callsite in the codebase is a mechanical swap (`print(` → `log(`).
//
//  Debug builds print to the Xcode console exactly as before. Release builds
//  now route through os.Logger into the unified system log instead of
//  compiling away to nothing — the previous behavior left Release builds with
//  zero observability, which turned a paywall/identity bug that only
//  reproduces in Release into a multi-day guessing game. Read the output by
//  connecting the device and opening Console.app (filter: subsystem
//  com.lazul.wingman), including shortly after the fact via the log archive.
//
//  Privacy note: interpolations are marked `.public` so Console shows real
//  values rather than <private>. Some callsites log the account email, so
//  that lands in the on-device system log (readable only with physical access
//  to an unlocked, trusted-paired device). Acceptable for now; revisit if
//  logging ever needs to ship quieter.
//
//  Do not rename back to `print` — the differing name keeps a grep for stray
//  direct prints easy.
//

import Foundation
import os

// `nonisolated` because the project sets
// SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor, which would otherwise pin this
// global to the main actor and forbid access from the nonisolated `log`.
// Safe: os.Logger is Sendable and this is a `let`.
private nonisolated let systemLogger = os.Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.lazul.wingman",
    category: "wingman"
)

// `nonisolated` so nonisolated callsites (background tasks, `Task.detached`,
// `.sink` on background queues, etc.) don't hop actors to emit a log line.
// `Swift.print` is itself nonisolated.
nonisolated func log(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    let line = items.map { String(describing: $0) }.joined(separator: separator)
    #if DEBUG
    Swift.print(line, terminator: terminator)
    #else
    systemLogger.info("\(line, privacy: .public)")
    #endif
}
