//
//  OnboardingView.swift
//  Wingman
//
//  Created by Adnan Khan on 29/11/2025.
//

import SwiftUI

struct OnboardingView: View {
    @StateObject private var viewModel = OnboardingViewModel()

    @State private var navigateToSignup = false
    @State private var navigateToLogin = false
    
    var body: some View {
        NavigationStack {
            VStack {
                
                // MARK: - Carousel
                TabView(selection: $viewModel.currentPage) {
                    ForEach(viewModel.pages.indices, id: \.self) { index in
                        let page = viewModel.pages[index]
                        
                        VStack(spacing: 10) {
                            Text(page.title)
                                .font(.title)
                                .fontWeight(.bold)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .lineSpacing(0)
                                .padding(.horizontal, 20)
                            
                            Text(page.description)
                                .font(.body)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                            
                            Image(page.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 280)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))  // hide default dots
                .frame(height: 500)
                
                // MARK: - Custom Page Indicator
                HStack {
                    ForEach(viewModel.pages.indices, id: \.self) { index in
                        Circle()
                            .frame(width: 8, height: 8)
                            .foregroundColor(viewModel.currentPage == index ? .black : .gray.opacity(0.3))
                    }
                }
                .padding(.bottom, 20)
                
                Spacer()
                
                // MARK: - Buttons
                VStack(spacing: 12) {
                    // Create Account Button
                    Button(action: {
                        navigateToSignup = true
                    }) {
                        Text("Create Account")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 10).stroke(Color.gray))
                    }
                    // Navigate to AuthView
                    .navigationDestination(isPresented: $navigateToSignup) {
                        AuthView(mode: .signup)
                    }
                    
                    // Log In Button
                    Button(action: {
                        navigateToLogin = true
                    }) {
                        Text("Log In")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .cornerRadius(10)
                    }
                    // Navigate to LoginView (replace with your LoginView)
                    .navigationDestination(isPresented: $navigateToLogin) {
                        AuthView(mode: .login)
                    }
                    
                    Button(action: { viewModel.skip() }) {
                        Text("Skip for now")
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal)
                
                Spacer().frame(height: 20)
            }
        }
    }
}

#Preview {
    OnboardingView()
}
