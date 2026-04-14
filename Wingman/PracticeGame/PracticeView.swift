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
                    // Show header unless this is the very first load (no data yet)
                    // or an error is being shown. This prevents the header from flashing
                    // during silent background refreshes on tab re-entry.
                    if !(viewModel.isLoading && viewModel.practices.isEmpty) && viewModel.errorMessage == nil {
                        headerView
                    }

                    // Only block with a full-screen loader on the very first load.
                    // Subsequent refreshes happen silently while the existing list stays visible.
                    if viewModel.isLoading && viewModel.practices.isEmpty {
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
                        .progressViewStyle(CircularProgressViewStyle(tint: .wingmanBlack))
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
            // Refresh the practice list and prefetch game data on every appearance.
            // fetchPractices picks up any newly-unlocked practices (so the previous
            // onAppear → checkForNewlyUnlockedPractices chain is unnecessary and
            // duplicated the network call).
            await viewModel.fetchPractices()
            await viewModel.prefetchGameData()
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
                .font(.manropeSemiBold(size: 20))
                .foregroundColor(.wingmanBlack)
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

                // MARK: - Coming Soon Footer
                Text("More scenarios coming soon")
                    .font(.manropeMedium(size: 13))
                    .foregroundColor(.gray.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Load game data then navigate
    private func loadAndNavigate(practice: Practice) async {
        guard !practice.isLocked else { return }
        viewModel.selectPractice(practice)

        // Fast path: prefetched data available, navigate instantly with no spinner.
        if let cached = viewModel.gameDataCache[practice.id] {
            loadedGameData = cached
            navigateToPracticeGame = true
            return
        }

        // Slow path fallback: cache miss (prefetch failed or still running).
        // Identical to prior behavior — shows the loading overlay then navigates.
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
                .progressViewStyle(CircularProgressViewStyle(tint: .wingmanBlack))
                .scaleEffect(1.2)
            Spacer()
        }
    }

    // MARK: - Error View
    private func errorView(message: String) -> some View {
        ZStack {
            VStack {
                
                // Back button at top
                HStack {
                    Button {
                        // Dismiss or go back - for tab-based view, this might not be needed
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 44, height: 44, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hidden() // Hide for now since Scenarios is a tab, not pushed view
                    
                    Spacer()
                }
                .padding(.leading, 8)
                .padding(.top, 8)
                
                Spacer()
                
                // Center Content
                VStack {
                    Text("Oops!")
                        .font(.manropeSemiBold(size: 24))
                        .foregroundColor(.black)
                    Text("Somthing went wrong")
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(.black)
                        .padding(.top, 2)
                    Text("Please Try again!")
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(.black)
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Bottom Button
                Button(action: {
                    Task { await viewModel.fetchPractices() }
                }) {
                    Text("Try Again")
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.black)
                        .cornerRadius(5)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Preview
#Preview {
    PracticeView()
        .environmentObject(AuthManager())
}
