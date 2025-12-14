//
//  DashboardView.swift
//  Wingman
//
//  Created by Adnan Khan on 15/12/2025.
//


import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Welcome to Dashboard")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("You're successfully logged in!")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Spacer()
                
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