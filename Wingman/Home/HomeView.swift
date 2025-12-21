//
//  HomeView.swift
//  Wingman
//

import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var navigateToPractice = false
    @State private var navigateToLogApproach = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // MARK: - Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Good Morning,")
                                .font(.manropeMedium(size: 24))
                                .foregroundColor(.black)
                            
                            Text(viewModel.userName)
                                .font(.manropeMedium(size: 24))
                                .foregroundColor(.black)
                        }
                        
                        Spacer()
                        
                        // Streak Badge
                        HStack(spacing: 4) {
                            Image("flame")
                                .font(.system(size: 14))
                                .foregroundColor(.black)
                            
                            Text("\(viewModel.currentStreak)")
                                .font(.manropeMedium(size: 16))
                                .foregroundColor(.black)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            
                            // MARK: - Daily Practice Card
                            // MARK: - Daily Practice Card
                            VStack(alignment: .leading, spacing: 0) {

                                ZStack(alignment: .topLeading) {

                                    // Watermark W (faint, left side)
                                     Image("wingman_logo")
                                           .resizable()
                                        .scaledToFit()
                                         .frame(width: 200, height: 200)
                                          .foregroundColor(Color.gray.opacity(0.13))   // if it's a template image
                                           .opacity(0.18)                               // keep very light
                                           .offset(x: -55, y: -38)                      // pushes it off-screen likdesign
                                            .frame(maxWidth: .infinity, maxHeight: .infinity,alignment:.topLeading)
                                              .clipped()

                                    VStack(spacing: 0) {

                                        Spacer(minLength: 20)

                                        // Title
                                        Text("Daily Practice")
                                            .font(.manropeSemiBold(size: 16))
                                            .foregroundColor(.black)
                                            .frame(maxWidth: .infinity, alignment: .center)

                                        // Subtitle
                                        Text("Suggested")
                                            .font(.manropeRegular(size: 12))
                                            .foregroundColor(Color.gray)
                                            .padding(.top, 4)
                                            .frame(maxWidth: .infinity, alignment: .center)

                                        Spacer(minLength: 16)

                                        // Start Button
                                        Button(action: {
                                            navigateToPractice = true
                                        }) {
                                            Text("Start")
                                                .font(.manropeSemiBold(size: 15))
                                                .foregroundColor(.white)
                                                .frame(maxWidth: .infinity)
                                                .frame(height: 48)
                                                .background(Color.black)
                                                .cornerRadius(5)
                                        }
                                        .padding(.horizontal, 20)

                                        Spacer(minLength: 16)
                                    }
                                }
                            }
                            .frame(height: 140)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal, 20)
                            
                            // MARK: - Log Today's Approach
                            Button(action: {
                                navigateToLogApproach = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 14))
                                        .foregroundColor(.black)
                                    
                                    Text("Log Today's Approach")
                                        .font(.manropeRegular(size: 15))
                                        .foregroundColor(.black)
                                    
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .padding(.horizontal, 20)
                                .background(Color.white)
                                .cornerRadius(5)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .padding(.horizontal, 20)
                            
                            // MARK: - Motivational Quote
                            HStack(spacing: 8) {
                                Image(systemName: "quote.bubble")
                                    .font(.system(size: 20))
                                    .foregroundColor(.gray.opacity(0.3))
                                
                                Text(viewModel.motivationalQuote)
                                    .font(.manropeRegular(size: 13))
                                    .foregroundColor(.gray)
                                    .italic()
                                    .multilineTextAlignment(.leading)
                                    .lineSpacing(2)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            
                            // MARK: - Continue Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Continue")
                                    .font(.manropeSemiBold(size: 18))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 20)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ContinueModuleCard(
                                            title: "Mindset & Foundations: Beliefs and Reframes",
                                            progress: 0.69,
                                            illustration: "continue_illust_1"
                                        )
                                        
                                        ContinueModuleCard(
                                            title: "Advanced Techniques",
                                            progress: 0.45,
                                            illustration: "continue_illust_2"
                                        )
                                        
                                        ContinueModuleCard(
                                            title: "Building Confidence",
                                            progress: 0.20,
                                            illustration: "continue_illust_3"
                                        )
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            
                            // MARK: - Your Modules Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Your Modules")
                                    .font(.manropeSemiBold(size: 18))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 20)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ModuleCard(
                                            title: "Mindset & Foundations",
                                            subtitle: "Suggested",
                                            illustration: "module_illust_1"
                                        )
                                        
                                        ModuleCard(
                                            title: "Body Language",
                                            subtitle: "Popular",
                                            illustration: "module_illust_2"
                                        )
                                        
                                        ModuleCard(
                                            title: "Conversation Skills",
                                            subtitle: "New",
                                            illustration: "module_illust_3"
                                        )
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            
                            Spacer().frame(height: 100)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToPractice) {
                PracticeView()
            }
            .navigationDestination(isPresented: $navigateToLogApproach) {
                LogApproachView()
            }
            .onAppear {
                print("👁️ HomeView appeared")
                viewModel.loadUserData()
            }
        }
    }
}

// MARK: - Continue Module Card
struct ContinueModuleCard: View {
    let title: String
    let progress: Double
    let illustration: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // Illustration placeholder
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.05))
                    .frame(height: 80)
                
                // Placeholder for illustration
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 40))
                    .foregroundColor(.gray.opacity(0.3))
            }
            
            // Title
            Text(title)
                .font(.manropeRegular(size: 13))
                .foregroundColor(.black)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(height: 40, alignment: .top)
            
            // Progress bar
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 2)
                        
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.black)
                            .frame(width: geometry.size.width * progress, height: 2)
                    }
                }
                .frame(height: 2)
                
                Text("\(Int(progress * 100))%")
                    .font(.manropeRegular(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .frame(width: 200)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Module Card
struct ModuleCard: View {
    let title: String
    let subtitle: String
    let illustration: String
    
    var body: some View {
        VStack(spacing: 16) {
            
            // Illustration
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.05))
                    .frame(height: 200)
                
                // Placeholder illustration
                Image(systemName: "person.2")
                    .font(.system(size: 60))
                    .foregroundColor(.gray.opacity(0.3))
            }
            
            VStack(spacing: 8) {
                // Title
                Text(title)
                    .font(.manropeSemiBold(size: 15))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Subtitle
                Text(subtitle)
                    .font(.manropeRegular(size: 12))
                    .foregroundColor(.gray)
                
                // Open Button
                Button(action: {
                    // Open module
                }) {
                    Text("Open")
                        .font(.manropeSemiBold(size: 14))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.black)
                        .cornerRadius(5)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(width: 240)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Log Approach View (Placeholder)
struct LogApproachView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Text("Log Today's Approach")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            Text("Coming Soon")
                .foregroundColor(.gray)
            
            Spacer()
            
            Button("Back") {
                dismiss()
            }
            .padding()
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview {
    HomeView()
}
