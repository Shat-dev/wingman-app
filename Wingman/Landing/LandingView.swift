//
//  OnboardingView.swift
//  Wingman
//
//  Created by Adnan Khan on 29/11/2025.
//

import SwiftUI

struct LandingView: View {
    @StateObject private var viewModel = LandingViewModel()
    @EnvironmentObject var authManager: AuthManager

    @State private var navigateToSignup = false
    @State private var navigateToLogin = false

    var body: some View {
        NavigationStack {
            VStack {

                // MARK: - Carousel
                TabView(selection: $viewModel.currentPage) {
                    ForEach(viewModel.pages.indices, id: \.self) { index in
                        let page = viewModel.pages[index]

                        VStack(spacing: 14) {

                            // MARK: - Heading
                            Text(page.title)
                                .font(.custom("Manrope-SemiBold", size: 32))
                                .foregroundColor(.black)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)

                            // MARK: - Description
                            Text(page.description)
                                .font(.custom("Manrope-Regular", size: 16))
                                .foregroundColor(Color.black.opacity(0.55))
                                .multilineTextAlignment(.leading)
                                .lineSpacing(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)

                            // MARK: - Image
                            Image(page.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 320)
                                .padding(.top, 10)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 520)

                

                // MARK: - CTA Buttons
                VStack(spacing: 12) {
                    
                    // MARK: - Page Indicator
                    HStack(spacing: 6) {
                        ForEach(viewModel.pages.indices, id: \.self) { index in
                            Circle()
                                .fill(viewModel.currentPage == index ? Color.black : Color.black.opacity(0.25))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.bottom, 5)

                    // Create Account
                    Button {
                        navigateToSignup = true
                    } label: {
                        Text("Create Account")
                            .font(.custom("Manrope-SemiBold", size: 16))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.black, lineWidth: 1)
                            )
                    }
                    .navigationDestination(isPresented: $navigateToSignup) {
                        AuthView(mode: .signup)
                    }

                    // Log In
                    Button {
                        navigateToLogin = true
                    } label: {
                        Text("Log In")
                            .font(.custom("Manrope-SemiBold", size: 16))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.black)
                            .cornerRadius(5)
                    }
                    .navigationDestination(isPresented: $navigateToLogin) {
                        AuthView(mode: .login)
                    }

                    // Skip
                    Button {
                        authManager.skipOnboarding()
                    } label: {
                        Text("Skip for now")
                            .font(.custom("Manrope-SemiBold", size: 16))
                            .foregroundColor(Color.black)
                            .underline()
                            .padding(.top, 6)
                    }
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 24)
            }
        }
    }
}


#Preview {
    LandingView()
        .environmentObject(AuthManager())
}
