//
//  DashboardView.swift
//  Wingman
//
//  Created by Adnan Khan on 15/12/2025.
//


import SwiftUI
import Supabase
import Auth

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showPaywall = false
    
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
                
                Spacer()
             
                VStack(spacing: 12) {
                    
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
