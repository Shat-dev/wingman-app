//
//  LoadingDotsView.swift
//  Wingman
//

import SwiftUI

// Small carousel-like black/gray dots.
//
// Uses `TimelineView(.periodic)` so the cadence is anchored to a clean
// reference time (computed from `context.date`) rather than depending on
// when `Timer.publish` happened to fire. This eliminates the multi-ms drift
// that the old `Timer.publish` + `@State + onReceive` pattern introduced
// against the display refresh.
struct LoadingDotsView: View {
    private let dotSize: CGFloat = 8

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            // Phase derived from elapsed time — no @State, no Timer.
            let phase = Int(context.date.timeIntervalSinceReferenceDate / 0.5) % 3

            HStack(spacing: 8) {
                ForEach(0..<3) { idx in
                    Circle()
                        .fill(idx == phase ? Color.wingmanBlack : Color.gray.opacity(0.45))
                        .frame(width: dotSize, height: dotSize)
                        .animation(.easeInOut(duration: 0.25), value: phase)
                }
            }
        }
    }
}
