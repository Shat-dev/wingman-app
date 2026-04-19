//
//  SettingsSheet.swift
//  Wingman
//

import SwiftUI
import Auth
import Supabase
import RevenueCat

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    @State private var goalNotifications = true
    @State private var showingDeleteAlert = false
    @State private var showDailyReadingGoal = false
    @State private var dailyReadingGoal = 10
    @State private var isDeleting = false // Loading state for account deletion
    @State private var isRestoringPurchases = false // Loading state for restore purchases
    @State private var showingErrorAlert = false
    @State private var errorMessage = ""
    @State private var showingSuccessAlert = false
    @State private var successMessage = ""
    @State private var safariLink: IdentifiableURL?
    let userName: String
    
    var body: some View {
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
                            .foregroundColor(.wingmanBlack)
                        
                        Spacer()
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.wingmanBlack)
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
                            // Provider icon reflects how the user actually signed in.
                            // Apple fallback covers the unauthenticated-at-render and
                            // email/unknown-provider cases — matches prior behaviour.
                            if isGoogleSignIn {
                                Image("auth_google_logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                            } else {
                                Image("apple_icon")
                                    .resizable()
                                    .renderingMode(.template)
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .foregroundColor(.wingmanBlack)
                            }

                            Text(getUserEmail())
                                .font(.manropeRegular(size: 16))
                                .foregroundColor(.wingmanBlack)

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
                                    .foregroundColor(.wingmanBlack)
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
                                .foregroundColor(.wingmanBlack)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $goalNotifications)
                            .labelsHidden()
                            .tint(.green)
                            .onChange(of: goalNotifications) { newValue in
                                HapticManager.shared.selection()
                                UserDefaults.standard.set(newValue, forKey: "goal_notifications")
                                
                                // Update notifications based on toggle
                                Task {
                                    await NotificationManager.shared.updateDailyReadingGoalNotification(
                                        enabled: newValue,
                                        goalMinutes: dailyReadingGoal
                                    )
                                }
                            }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    
                    // MARK: - Restore Purchase
                    Button(action: {
                        Task {
                            await restorePurchase()
                        }
                    }) {
                        HStack(spacing: 8) {
                            if isRestoringPurchases {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.7)
                            }
                            Text(isRestoringPurchases ? "Restoring..." : "Restore Purchase")
                                .font(.manropeMedium(size: 14))
                                .foregroundColor(.wingmanBlack)
                                .underline()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(isRestoringPurchases)
                    .padding(.horizontal, 24)
                    .padding(.top,40)
                    .padding(.bottom, 16)
                    
                    // MARK: - Manage Subscriptions
                    Button(action: {
                        manageSubscriptions()
                    }) {
                        Text("Manage Subscriptions")
                            .font(.manropeMedium(size: 14))
                            .foregroundColor(.wingmanBlack)
                            .underline()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    // MARK: - Terms of Service
                    Button(action: {
                        if let url = URL(string: Constants.TERMS_CONDITIONS_URL) {
                            safariLink = IdentifiableURL(url: url)
                        }
                    }) {
                        Text("Terms of Service")
                            .font(.manropeMedium(size: 14))
                            .foregroundColor(.wingmanBlack)
                            .underline()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    // MARK: - Privacy Policy
                    Button(action: {
                        if let url = URL(string: Constants.PRIVACY_POLICY_URL) {
                            safariLink = IdentifiableURL(url: url)
                        }
                    }) {
                        Text("Privacy Policy")
                            .font(.manropeMedium(size: 14))
                            .foregroundColor(.wingmanBlack)
                            .underline()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)

                    // MARK: - Delete Account
                    Button(action: {
                        HapticManager.shared.warning()
                        showingDeleteAlert = true
                    }) {
                        Text("Delete Account")
                            .font(.manropeMedium(size: 14))
                            .foregroundColor(Color(hex: "#E53935"))
                            .underline()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .disabled(isDeleting)
                    .opacity(isDeleting ? 0.5 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: isDeleting)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    
                    // MARK: - Version
                    Text("V \(getAppVersion())")
                        .font(.manropeMedium(size: 14))
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    
                    
                    // MARK: - Log Out Button
                    Button(action: {
                        HapticManager.shared.mediumImpact()
                        logOut()
                    }) {
                        Text("Log Out")
                            .font(.manropeSemiBold(size: 16))
                            .foregroundColor(.wingmanBlack)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.white)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.wingmanBlack, lineWidth: 1)
                            )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                    .padding(.top, 40)
                }
                
                // MARK: - Simple Loader Overlay (inside ZStack to maintain sheet size)
                if isDeleting {
                    Color.white.opacity(0.9)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#1A1A1A")))
                        .scaleEffect(1.2)
                }
            }
            .disabled(isDeleting) // Disable interaction during deletion
        .animation(.easeInOut, value: isDeleting)
        .alert("Delete Account", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteAccount()
            }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone.")
        }
        .alert("Error", isPresented: $showingErrorAlert) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: showingErrorAlert) { showing in
            if showing { HapticManager.shared.error() }
        }
        .alert("Success", isPresented: $showingSuccessAlert) {
            Button("OK") { }
        } message: {
            Text(successMessage)
        }
        .onChange(of: showingSuccessAlert) { showing in
            if showing { HapticManager.shared.success() }
        }
        .sheet(isPresented: $showDailyReadingGoal) {
            DailyReadingGoalSheet(currentGoal: dailyReadingGoal) { newGoal in
                dailyReadingGoal = newGoal
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(20)
        }
        .sheet(item: $safariLink) { link in
            SafariView(url: link.url)
                .ignoresSafeArea()
        }
        .onAppear {
            loadSettings()
        }
    }
    
    private func getAppVersion() -> String {
        guard let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return "Unknown"
        }
        return version
    }
    
    private func loadSettings() {
        dailyReadingGoal = UserDefaults.standard.integer(forKey: "daily_reading_goal")
        if dailyReadingGoal == 0 {
            dailyReadingGoal = 10 // Default value
        }
        goalNotifications = UserDefaults.standard.bool(forKey: "goal_notifications")
        
        // If goal notifications is true but UserDefaults returns false for a first-time user,
        // we should keep the default true value. Only change if explicitly set.
        if !UserDefaults.standard.bool(forKey: "goal_notifications") &&
           UserDefaults.standard.object(forKey: "goal_notifications") == nil {
            goalNotifications = true // Default to enabled for new users
            UserDefaults.standard.set(true, forKey: "goal_notifications")
        }
    }
    
    private func getUserEmail() -> String {
        return UserDefaults.standard.string(forKey: "user_email") ?? ""
    }

    /// True when the currently-authenticated user signed in with Google.
    /// Reads Supabase's `app_metadata.provider` field set by the auth layer at
    /// sign-in time. Any other value (apple / email / nil / no user) falls
    /// back to the Apple icon so Settings never renders a broken state.
    private var isGoogleSignIn: Bool {
        guard let user = SupabaseManager.shared.client.auth.currentUser else {
            return false
        }
        let provider = user.appMetadata["provider"]?.stringValue?.lowercased() ?? ""
        return provider == "google"
    }
    
    private func restorePurchase() async {
        isRestoringPurchases = true
        
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            let hasEntitlement = customerInfo.entitlements[Constants.ENTITLEMENT_ID]?.isActive == true
            
            if hasEntitlement {
                await MainActor.run {
                    successMessage = "Purchases restored successfully!"
                    showingSuccessAlert = true
                }
                log("✅ SettingsSheet: Purchases restored")
            } else {
                await MainActor.run {
                    errorMessage = "No active subscriptions found to restore"
                    showingErrorAlert = true
                }
                log("⚠️ SettingsSheet: No purchases to restore")
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to restore purchases. Please try again."
                showingErrorAlert = true
            }
            log("❌ SettingsSheet: Restore failed: \(error)")
        }
        
        isRestoringPurchases = false
    }
    
    private func manageSubscriptions() {
        log("Manage Subscriptions tapped")
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }
    
    private func deleteAccount() {
        log("🗑️ Delete account confirmation received")
        
        Task {
            do {
                // Start loading state
                await MainActor.run {
                    isDeleting = true
                    log("🗑️ Showing deletion loading state...")
                }
                
                log("🗑️ Initiating account deletion process...")
                
                // Call AuthManager's secure deletion method
                try await authManager.deleteAccount()
                
                log("✅ Account deletion successful")
                
                // Account deletion was successful - AuthManager has already:
                // 1. Deleted all user data from database
                // 2. Deleted the auth account
                // 3. Cleared all local data
                // 4. Updated auth state (isAuthenticated = false)
                
                await MainActor.run {
                    // Stop loading state
                    isDeleting = false
                    
                    // Dismiss the settings sheet
                    dismiss()
                    
                    // The app will automatically navigate to login/onboarding screen
                    // because AuthManager has set isAuthenticated = false
                    log("✅ Account deletion completed - returning to auth flow")
                }
                
            } catch AccountDeletionError.notAuthenticated {
                await MainActor.run {
                    isDeleting = false
                    log("❌ User not authenticated")
                    // Handle error - maybe show an alert
                }
            } catch AccountDeletionError.invalidSession {
                await MainActor.run {
                    isDeleting = false
                    log("❌ Invalid session")
                    // Handle error - session might have expired
                }
            } catch AccountDeletionError.networkError(let message) {
                await MainActor.run {
                    isDeleting = false
                    log("❌ Network error during deletion: \(message)")
                    // Show network error to user
                    showDeletionError("Network error: Please check your connection and try again.")
                }
            } catch AccountDeletionError.deletionFailed(let message) {
                await MainActor.run {
                    isDeleting = false
                    log("❌ Account deletion failed: \(message)")
                    // Show server error to user
                    showDeletionError("Deletion failed: \(message)")
                }
            } catch AccountDeletionError.invalidResponse {
                await MainActor.run {
                    isDeleting = false
                    log("❌ Invalid response from server")
                    showDeletionError("Server error: Please try again later.")
                }
            } catch {
                await MainActor.run {
                    isDeleting = false
                    log("❌ Unexpected error during account deletion: \(error.localizedDescription)")
                    showDeletionError("An unexpected error occurred. Please try again.")
                }
            }
        }
    }
    
    private func showDeletionError(_ message: String) {
        errorMessage = message
        showingErrorAlert = true
        log("🚨 Deletion Error: \(message)")
    }
    
    private func logOut() {
        Task {
            do {
                try await SupabaseManager.shared.client.auth.signOut()
                SupabaseManager.shared.clearCurrentUser()
                
                await MainActor.run {
                    dismiss()
                    log("Logged out successfully")
                }
            } catch {
                log("Error logging out: \(error.localizedDescription)")
            }
        }
    }
}

#Preview {
    SettingsSheet(userName: "Shat")
        .environmentObject(AuthManager())
}
