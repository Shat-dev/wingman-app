//
//  CoursesView.swift
//  Wingman
//
//  Created by Adnan Khan on 22/12/2025.
//


//
//  PlaceholderViews.swift
//  Wingman
//

import SwiftUI
import Auth

// MARK: - Courses View
struct CoursesView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Image(systemName: "play.rectangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray.opacity(0.3))
                    
                    Text("Courses")
                        .font(.manropeSemiBold(size: 28))
                        .foregroundColor(.black)
                    
                    Text("Coming Soon")
                        .font(.manropeRegular(size: 16))
                        .foregroundColor(.gray)
                    
                    Text("Learn at your own pace with structured lessons and real-world scenarios.")
                        .font(.manropeRegular(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Profile View
struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    
                    // Profile Header
                    VStack(spacing: 12) {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 80, height: 80)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.gray.opacity(0.6))
                            )
                        
                        if let email = authManager.currentUser?.email {
                            Text(email)
                                .font(.manropeSemiBold(size: 18))
                                .foregroundColor(.black)
                        } else {
                            Text("User")
                                .font(.manropeSemiBold(size: 18))
                                .foregroundColor(.black)
                        }
                        
                        Text("Member since \(memberSince())")
                            .font(.manropeRegular(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 40)
                    
                    // Stats
                    HStack(spacing: 40) {
                        StatItem(value: "0", label: "Approaches")
                        StatItem(value: "0", label: "Streak")
                        StatItem(value: "0", label: "Lessons")
                    }
                    .padding(.vertical, 24)
                    
                    Spacer()
                    
                    // Settings Options
                    VStack(spacing: 16) {
                        ProfileOption(icon: "gear", title: "Settings")
                        ProfileOption(icon: "questionmark.circle", title: "Help & Support")
                        ProfileOption(icon: "info.circle", title: "About")
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Sign Out Button
                        Button(action: {
                            Task {
                                await authManager.signOut()
                            }
                        }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 18))
                                    .foregroundColor(.red)
                                
                                Text("Sign Out")
                                    .font(.manropeRegular(size: 16))
                                    .foregroundColor(.red)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private func memberSince() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: Date())
    }
}

// MARK: - Stat Item
struct StatItem: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Text(value)
                .font(.manropeSemiBold(size: 24))
                .foregroundColor(.black)
            
            Text(label)
                .font(.manropeRegular(size: 12))
                .foregroundColor(.gray)
        }
    }
}

// MARK: - Profile Option
struct ProfileOption: View {
    let icon: String
    let title: String
    
    var body: some View {
        Button(action: {
            // Handle tap
        }) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.black)
                    .frame(width: 24)
                
                Text(title)
                    .font(.manropeRegular(size: 16))
                    .foregroundColor(.black)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
    }
}

#Preview("Courses") {
    CoursesView()
}

#Preview("Profile") {
    ProfileView()
        .environmentObject(AuthManager())
}
