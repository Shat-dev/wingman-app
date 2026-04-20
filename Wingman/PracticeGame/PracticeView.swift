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

    // Feature-gate paywall for scenario taps (free users).
    // Progression-locked scenarios are disabled at the card level and never
    // reach the loadAndNavigate path — only unlocked scenarios hit the gate.
    @State private var showPaywall: Bool = false

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
            .subscriptionGate(isPresented: $showPaywall)
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
    // Read from `display_name` only; never derive from email. Falls back to
    // "You" (generic dialogue label fits the practice-game context better
    // than "User" here). Read via the already-observed @Published currentUser
    // on AuthManager so this view reactively updates on display_name edits
    // and avoids a singleton dereference on every body render.
    private var userDisplayName: String {
        if let user = authManager.currentUser,
           let name = user.userMetadata["display_name"]?.stringValue,
           !name.trimmingCharacters(in: .whitespaces).isEmpty {
            return name
        }
        return "You"
    }

    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Text("Scenarios")
                .font(.manropeMedium(size: 24))
                .foregroundColor(.wingmanBlack)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    // MARK: - Practice List View
    private var practiceListView: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    Color.clear.frame(height: 0).id("top")
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
            .onReceive(NotificationCenter.default.publisher(for: .scrollToTopTab)) { note in
                guard (note.object as? Int) == 2 else { return }
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo("top", anchor: .top)
                }
            }
        }
    }

    // MARK: - Load game data then navigate
    private func loadAndNavigate(practice: Practice) async {
        guard !practice.isLocked else { return }

        // Subscription gate — free users see the paywall instead of
        // navigating into the scenario. Placed after the progression-lock
        // guard so locked scenarios continue to no-op silently (matches
        // the "reduce paywall spam" requirement for progression locks).
        guard authManager.hasActiveSubscription else {
            showPaywall = true
            return
        }

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
                            .font(.system(size: 22))
                            .foregroundColor(.wingmanBlack)
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
                        .foregroundColor(.wingmanBlack)
                    Text("Something went wrong")
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(.wingmanBlack)
                        .padding(.top, 2)
                    Text("Please Try again!")
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(.wingmanBlack)
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
                        .background(Color.wingmanBlack)
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
