//
//  SplashView.swift
//  Wingman
//
//  Created by Adnan Khan on 29/11/2025.
//
import SwiftUI

struct SplashView: View {
    @State private var isActive = false

    var body: some View {
        if isActive {
            LandingView()  // Your main screen
        } else {
            ZStack {
                Color.white.ignoresSafeArea()
                
                Image("wingman_logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200)
                    .opacity(0.9)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        isActive = true
                    }
                }
            }
        }
    }
}
#Preview {
    SplashView()
}
