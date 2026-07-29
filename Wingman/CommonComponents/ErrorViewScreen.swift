//
//  ErrorViewScreen.swift
//  Wingman
//
//  Created by Adnan Khan on 18/02/2026.
//


import SwiftUI

struct ErrorViewScreen: View {
    
    var message: String = "Something went wrong"
    var retryAction: () -> Void
    
    var body: some View {
        ZStack {
            
            // Background
            Color(.systemGray6)
                .ignoresSafeArea()
            
            VStack {
                
                Spacer()
                
                // Center Content
                VStack(spacing: 12) {
                    
                    Text("Oops!")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(.wingmanBlack)
                    
                    Text(message)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.wingmanBlack.opacity(0.7))
                        .multilineTextAlignment(.center)
                    
                    Text("Please try again!")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.wingmanBlack.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Bottom Button
                Button(action: {
                    retryAction()
                }) {
                    Text("Try Again")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.wingmanBlack)
                        .cornerRadius(10)
                }
                .buttonStyle(ScalePressStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }
}