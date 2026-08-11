//
//  TapToContinueButton.swift
//  Wingman
//

import SwiftUI

struct TapToContinueButton: View {
    let action: () -> Void
    @State private var isVisible = false

    var body: some View {
        Button(action: {
            HapticManager.shared.tap()
            action()
        }) {
            Text("Tap to continue")
                .font(.manropeRegular(size: 16))
                .foregroundColor(.gray)
                .opacity(isVisible ? 1 : 0)
                .animation(.easeIn(duration: 0.5), value: isVisible)
        }
        .buttonStyle(ScalePressStyle())
        .onAppear {
            // Reduced from 1.5s to 0.6s. The right-side tap zone in the
            // statistic view already accepts taps independent of this
            // button's visibility, so the user can always advance — this
            // delay is purely the visual hint reveal.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                isVisible = true
            }
        }
    }
}
