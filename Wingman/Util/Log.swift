//
//  Log.swift
//  Wingman
//
//  Debug-only logging shim. Signature-compatible with `Swift.print` so every
//  existing callsite in the codebase is a mechanical swap (`print(` → `log(`).
//  In Release builds (App Store archives) the `DEBUG` compilation condition
//  is not set, so the body compiles away to an empty function — no console
//  output reaches the device, and the compiler can inline the empty call away.
//
//  Do not rename back to `print` — the whole point is that the function name
//  differs from `Swift.print` so a future grep for stray direct prints is easy.
//

import Foundation

// `nonisolated` is required because the project sets
// `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, which would otherwise pin this
// free function to the main actor and force every nonisolated callsite
// (background tasks, `Task.detached`, `.sink` on background queues, etc.) to
// hop actors just to emit a debug line. `Swift.print` is itself nonisolated.
nonisolated func log(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    #if DEBUG
    let line = items.map { String(describing: $0) }.joined(separator: separator)
    Swift.print(line, terminator: terminator)
    #endif
}
