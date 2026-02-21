//
//  PracticeView.swift
//  Wingman
//

import SwiftUI
import Supabase

struct PracticeView: View {

    // MARK: - Properties
    @StateObject private var viewModel = PracticeViewModel()
    @State private var navigateToPracticeGame: Bool = false
    @State private var loadedGameData: PracticeGameData? = nil
    @State private var isLoadingGame: Bool = false
    @EnvironmentObject var authManager: AuthManager

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 0) {
                    headerView

                    if viewModel.isLoading {
                        loadingView
                    } else if let errorMessage = viewModel.errorMessage {
                        errorView(message: errorMessage)
                    } else {
                        practiceListView
                    }
                }

                // Full-screen loading overlay when fetching game scenes
                if isLoadingGame {
                    Color.white.opacity(0.85).ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#1A1A1A")))
                        .scaleEffect(1.4)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToPracticeGame) {
                if let gameData = loadedGameData {
                    PracticeGame(
                        gameData: gameData,
                        userName: userDisplayName
                    )
                }
            }
        }
        .task {
            await viewModel.fetchPractices()
        }
    }

    // MARK: - Derived user display name
    private var userDisplayName: String {
        if let user = SupabaseManager.shared.client.auth.currentUser {
            if let name = user.userMetadata["display_name"]?.stringValue,
               !name.trimmingCharacters(in: .whitespaces).isEmpty {
                return name
            }
            if let email = user.email,
               let local = email.split(separator: "@").first, !local.isEmpty {
                return String(local)
            }
        }
        return "You"
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Text("Scenarios")
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
                        Task {
                            await loadAndNavigate(practice: practice)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Load game data then navigate
    private func loadAndNavigate(practice: Practice) async {
        guard !practice.isLocked else { return }
        viewModel.selectPractice(practice)
        isLoadingGame = true
        if let gameData = await viewModel.fetchGameData(for: practice) {
            loadedGameData = gameData
            isLoadingGame = false
            navigateToPracticeGame = true
        } else {
            isLoadingGame = false
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
                Task { await viewModel.fetchPractices() }
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
