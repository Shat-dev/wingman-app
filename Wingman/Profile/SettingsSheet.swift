//
//  SettingsSheet.swift
//  Wingman
//

import SwiftUI
import Auth
import Supabase

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var goalNotifications = true
    @State private var showingDeleteAlert = false
    @State private var showDailyReadingGoal = false
    @State private var dailyReadingGoal = 10
    let userName: String
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - Grabber
                    HStack {
                        Capsule()
                            .fill(Color(red: 0.85, green: 0.85, blue: 0.85))
                            .frame(width: 36, height: 5)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 6)
                    
                    // MARK: - Custom Title Row
                    HStack {
                        Text("Settings")
                            .font(.manropeMedium(size: 18))
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.black)
                                .padding(.top, -20)
                                .padding(.trailing, -2)
                                .opacity(0.5)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                    
                    // MARK: - Email Section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.manropeMedium(size: 14))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 8) {
                            Image("apple_icon")
                                .font(.system(size: 16))
                                .foregroundColor(.black)
                            
                            Text(getUserEmail())
                                .font(.manropeRegular(size: 16))
                                .foregroundColor(.black)
                            
                            Spacer()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    
                    // MARK: - Daily Reading Goal
                    Button(action: {
                        showDailyReadingGoal = true
                    }) {
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Daily Reading Goal")
                                    .font(.manropeMedium(size: 14))
                                    .foregroundColor(.gray)
                                
                                Text("\(dailyReadingGoal) min / day")
                                    .font(.manropeRegular(size: 16))
                                    .foregroundColor(.black)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .buttonStyle(.plain)
                    
                    // MARK: - Goal Notifications Toggle
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Goal Notifications")
                                .font(.manropeMedium(size: 14))
                                .foregroundColor(.gray)
                            
                            Text(goalNotifications ? "ON" : "OFF")
                                .font(.manropeRegular(size: 16))
                                .foregroundColor(.black)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $goalNotifications)
                            .labelsHidden()
                            .tint(.green)
                            .onChange(of: goalNotifications) { newValue in
                                UserDefaults.standard.set(newValue, forKey: "goal_notifications")
                            }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    // MARK: - Restore Purchase
                    Button(action: {
                        restorePurchase()
                    }) {
                        Text("Restore Purchase")
                            .font(.manropeMedium(size: 14))
                            .foregroundColor(.black)
                            .underline()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top,40)
                    .padding(.bottom, 16)
                    
                    // MARK: - Manage Subscriptions
                    Button(action: {
                        manageSubscriptions()
                    }) {
                        Text("Manage Subscriptions")
                            .font(.manropeMedium(size: 14))
                            .foregroundColor(.black)
                            .underline()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    
                    // MARK: - Delete Account
                    Button(action: {
                        showingDeleteAlert = true
                    }) {
                        Text("Delete Account")
                            .font(.manropeMedium(size: 14))
                            .foregroundColor(.red)
                            .underline()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    
                    // MARK: - Version
                    Text("V 6.9.0")
                        .font(.manropeMedium(size: 14))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    
                    Spacer()
                    
                    // MARK: - Log Out Button
                    Button(action: {
                        logOut()
                    }) {
                        Text("Log Out")
                            .font(.manropeSemiBold(size: 16))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.black, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
            .alert("Delete Account", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAccount()
                }
            } message: {
                Text("Are you sure you want to delete your account? This action cannot be undone.")
            }
            .sheet(isPresented: $showDailyReadingGoal) {
                DailyReadingGoalSheet(currentGoal: dailyReadingGoal) { newGoal in
                    dailyReadingGoal = newGoal
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(20)
            }
        }
        .onAppear {
            loadSettings()
        }
    }
    
    private func loadSettings() {
        dailyReadingGoal = UserDefaults.standard.integer(forKey: "daily_reading_goal")
        if dailyReadingGoal == 0 {
            dailyReadingGoal = 10 // Default value
        }
        goalNotifications = UserDefaults.standard.bool(forKey: "goal_notifications")
    }
    
    private func getUserEmail() -> String {
        return UserDefaults.standard.string(forKey: "user_email") ?? "shat.myapantsx10@gmail.com"
    }
    
    private func restorePurchase() {
        // TODO: Implement restore purchase logic
        print("Restore Purchase tapped")
    }
    
    private func manageSubscriptions() {
        // TODO: Open App Store subscriptions page
        print("Manage Subscriptions tapped")
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
    
    private func deleteAccount() {
        // TODO: Delete account from Supabase
        Task {
            do {
                // Delete from Supabase
                try await SupabaseManager.shared.client.auth.signOut()
                
                // Clear local data
                SupabaseManager.shared.clearCurrentUser()
                
                // Dismiss and navigate to login screen
                await MainActor.run {
                    dismiss()
                    // TODO: Navigate to login screen
                    print("Account deleted successfully")
                }
            } catch {
                print("Error deleting account: \(error.localizedDescription)")
            }
        }
    }
    
    private func logOut() {
        // TODO: Sign out from Supabase
        Task {
            do {
                try await SupabaseManager.shared.client.auth.signOut()
                SupabaseManager.shared.clearCurrentUser()
                
                await MainActor.run {
                    dismiss()
                    // TODO: Navigate to login screen
                    print("Logged out successfully")
                }
            } catch {
                print("Error logging out: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    SettingsSheet(userName: "Shat")
}
