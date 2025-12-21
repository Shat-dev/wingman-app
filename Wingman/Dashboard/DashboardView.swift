//
//  DashboardView.swift
//  Wingman
//
//  Created by Adnan Khan on 15/12/2025.
//


import SwiftUI
import Foundation
import Combine
import Supabase
import Auth

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showPaywall = false
    @State private var navigateToPractice = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Welcome to Dashboard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("You're successfully logged in!")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                if let email = authManager.currentUser?.email {
                    Text("Email: \(email)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Safely read user metadata from Supabase (AnyJSON-backed)
                if let user = SupabaseManager.shared.client.auth.currentUser {
                    let name = user.userMetadata["display_name"]?.stringValue
                    let onboardingCompleted = user.userMetadata["onboarding_completed"]?.boolValue
                    let updatedAt = user.userMetadata["updated_at"]?.stringValue
                    
                    // Display some of it if available
                    VStack(spacing: 4) {
                        if let name = name, !name.isEmpty {
                            Text("Name: \(name)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        if let onboardingCompleted = onboardingCompleted {
                            Text("Onboarding Completed: \(onboardingCompleted ? "Yes" : "No")")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        if let updatedAt = updatedAt, !updatedAt.isEmpty {
                            Text("Updated At: \(updatedAt)")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .onAppear {
                        // Debug prints moved out of the View builder
                        print(name ?? "")
                        print(onboardingCompleted ?? false)
                        print(updatedAt ?? "")
                    }
                }
                
                Spacer()
             
                VStack(spacing: 12) {
                    // Daily Practice Button
                    Button(action: {
                        navigateToPractice = true
                    }) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 20))
                            Text("Daily Practice")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.blue)
                        .cornerRadius(10)
                    }
                    .navigationDestination(isPresented: $navigateToPractice) {
                        PracticeView()
                    }
                    
                    // Payment Button (for testing)
                    Button(action: {
                        showPaywall = true
                    }) {
                        Text("Payment test")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.green)
                            .cornerRadius(10)
                    }
                    .navigationDestination(isPresented: $showPaywall) {
                        PaywallView()
                    }
                    
                    // Reset Questions (for testing)
                    Button(action: {
                        authManager.resetQuestions()
                    }) {
                        Text("Reset Questions (Test)")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.orange)
                            .cornerRadius(10)
                    }
                    
                    // Logout Button
                    Button(action: {
                        Task {
                            await authManager.signOut()
                        }
                    }) {
                        Text("Sign Out")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(.white)
                            .background(Color.red)
                            .cornerRadius(10)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .navigationTitle("Dashboard")
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AuthManager())
}
