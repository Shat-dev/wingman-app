//
//  HomeView.swift
//  Wingman
//

import SwiftUI
import Auth
import Supabase

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var navigateToPractice = false
    @State private var showLogApproachSheet = false
    
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
                            
                            // Show user name like Dashboard (from Supabase userMetadata["display_name"])
                            if let user = SupabaseManager.shared.client.auth.currentUser {
                                let name = user.userMetadata["display_name"]?.stringValue
                                
                                if let name = name, !name.isEmpty {
                                    Text(name)
                                        .font(.manropeMedium(size: 24))
                                        .foregroundColor(.black)
                                } else if let email = user.email, !email.isEmpty {
                                    Text(email)
                                        .font(.manropeMedium(size: 24))
                                        .foregroundColor(.black)
                                } else {
                                    Text("User")
                                        .font(.manropeMedium(size: 24))
                                        .foregroundColor(.black)
                                }
                            } else {
                                Text("User")
                                    .font(.manropeMedium(size: 24))
                                    .foregroundColor(.black)
                            }
                        }
                        
                        Spacer()
                        
                        // MARK: - Streak Badge
                        HStack(spacing: 6) {

                            Image("flame")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .padding(.leading, 16)

                            Text("\(viewModel.currentStreak)")
                                .font(.manropeMedium(size: 20))
                                .padding(.trailing,16)
                        }
                        .foregroundColor(.black)
                        .frame(width: 64, height: 44)              // matches visual size
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.black.opacity(0.15), lineWidth: 1)
                        )
                        .cornerRadius(5)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            
                            // MARK: - Daily Practice Card
                            VStack(spacing: 0) {

                                VStack(spacing: 0) {

                                    Text("Daily Practice")
                                        .font(.manropeMedium(size: 20))
                                        .foregroundColor(.black)
                                        .padding(.top, 20)
                                        .frame(maxWidth: .infinity)

                                    Text("Suggested")
                                        .font(.manropeMedium(size: 14))
                                        .foregroundColor(.gray)
                                        .padding(.top, 8)
                                        .frame(maxWidth: .infinity)

                                   

                                    Button("Start") {
                                        navigateToPractice = true
                                    }
                                    .font(.manropeSemiBold(size: 16))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(Color.black)
                                    .cornerRadius(5)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 20)
                                    .padding(.top,40)
                                }
                            }
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(
                                // 🔥 BIG WATERMARK (intentionally larger than card)
                                Image("wingman_logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 300, height: 280)          // larger than card
                                    .opacity(0.12)
                                    .padding(.top, -100)         // slight bleed
                                    .padding(.trailing, 155),   // slight bleed
                                alignment: .topTrailing
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal, 20)
                            
                            // MARK: - Log Today's Approach
                            Button(action: {
                                showLogApproachSheet = true
                            }) {
                                HStack(spacing: 10) {
                                    Image("feather")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 22, height: 22)
                                        .foregroundColor(.black)          // works if the asset renders as template

                                    Text("Log Encounter")
                                        .font(.manropeSemiBold(size: 16))
                                        .foregroundColor(.black)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.black.opacity(0.35), lineWidth: 1)
                                )
                                .cornerRadius(5)
                            }
                            .padding(.horizontal, 20)
                            
                            Divider().background(Color.gray.opacity(0.2))
                            
                            // MARK: - Motivational Quote
                            HStack(alignment: .top, spacing: 10) {

                                // Large faint quote mark (asset)
                                Image("quote_sign")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)     // size like design
                                    .padding(.top, -30)                 // aligns with first text line

                                Text(viewModel.motivationalQuote)
                                    .font(.georgiaItalic(size: 16)) // matches screenshot style
                                    .foregroundColor(Color.black.opacity(0.75))
                                    
                                    .multilineTextAlignment(.leading)
                                    .lineSpacing(3)
                                    .padding(.top, 6)                 // pushes text down to match design

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)

                            
                            Divider().background(Color.gray.opacity(0.2))
                            
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
            .sheet(isPresented: $showLogApproachSheet) {
                LogApproachBottomSheet(isPresented: $showLogApproachSheet)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(20)
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

#Preview {
    HomeView()
}
