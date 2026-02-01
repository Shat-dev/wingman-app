//
//  PracticeView.swift
//  Wingman
//
//  Created by Adnan Khan on 23/01/2026.
//

import SwiftUI
import Supabase


struct PracticeView: View {

    // MARK: - Properties
    @StateObject private var viewModel = PracticeViewModel()
    @State private var navigateToPracticeGame: Bool = false
    @EnvironmentObject var authManager: AuthManager

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.white
                    .ignoresSafeArea()

                // Content
                VStack(spacing: 0) {
                    // Header
                    headerView

                    // Practice List
                    if viewModel.isLoading {
                        loadingView
                    } else if let errorMessage = viewModel.errorMessage {
                        errorView(message: errorMessage)
                    } else {
                        practiceListView
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToPracticeGame) {
                // Open PracticeGame.swift
                PracticeGame(
                    gameData: MockData.sampleGame, // TODO: map to selected practice later
                    userName: userDisplayName
                )
            }
        }
        .task {
            await viewModel.fetchPractices()
        }
    }

    // MARK: - Derived user display name
    private var userDisplayName: String {
        // Prefer Supabase user metadata "display_name" saved during onboarding
        if let user = SupabaseManager.shared.client.auth.currentUser {
            if let name = user.userMetadata["display_name"]?.stringValue, !name.trimmingCharacters(in: .whitespaces).isEmpty {
                return name
            }
            // Fallback to email local-part
            if let email = user.email, let local = email.split(separator: "@").first, !local.isEmpty {
                return String(local)
            }
        }
        // Final fallback
        return "You"
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Text("Practice")
                .font(.manropeBold(size: 28))
                .foregroundColor(Color(hex: "#1A1A1A"))

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Practice List View
    private var practiceListView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.practices) { practice in
                    PracticeCardView(practice: practice) {
                        viewModel.selectPractice(practice)
                        navigateToPracticeGame = true
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Bottom padding for tab bar
        }
    }

    // MARK: - Loading View
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#1A1A1A")))
                .scaleEffect(1.2)
            Spacer()
        }
    }

    // MARK: - Error View
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "#999999"))

            Text(message)
                .font(.manropeMedium(size: 14))
                .foregroundColor(Color(hex: "#666666"))
                .multilineTextAlignment(.center)

            Button(action: {
                Task {
                    await viewModel.fetchPractices()
                }
            }) {
                Text("Try Again")
                    .font(.manropeSemiBold(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#1A1A1A"))
                    .cornerRadius(8)
            }

            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Preview
#Preview {
    PracticeView()
        .environmentObject(AuthManager())
}
