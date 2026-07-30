//
//  ProfileView.swift
//  Wingman
//

import SwiftUI
import Combine
import Supabase
import PostHog

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showApproachesLogged = false
    @State private var showSaveProgress = false
    // Bound directly to the shared stores so any mutation elsewhere (logging,
    // editing, deleting an approach, completing daily practice, editing name)
    // re-renders the card instantly without waiting for onAppear/pull-to-refresh.
    @StateObject private var approachService = ApproachService.shared
    @StateObject private var streakStore = StreakStore.shared
    @StateObject private var userProfileStore = UserProfileStore.shared

    // Rate-limits the onAppear refresh so rapid tab-thrashing (Home→Profile→
    // Home→Profile) doesn't fire 3 RPCs per round-trip. A 5s window is short
    // enough that a user who navigates away and performs a real action before
    // returning still sees a refresh on arrival.
    @State private var lastRefreshedAt: Date?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // MARK: - Custom Title Row (left-aligned with trailing gear) — FIXED
                    HStack {
                        Text("Profile")
                            .font(.manropeMedium(size: 24))
                            .foregroundColor(.wingmanBlack)

                        Spacer()

                        Button(action: {
                            showSettings = true
                        }) {
                            Image(systemName: "gearshape")
                                .font(.manropeSemiBold(size: 20))
                                .foregroundColor(.wingmanBlack)
                        }
                        .buttonStyle(ScalePressStyle())
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                    
                    // Divider if you want a visual separation (optional)
                    // Divider().background(Color.gray.opacity(0.2))
                    
                    // MARK: - Scrollable Content
                    ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            Color.clear.frame(height: 0).id("top")

                            // MARK: - User Profile Card
                            Button(action: {
                                showEditProfile = true
                            }) {
                                HStack(spacing: 12) {
                                    // Avatar placeholder
                                    ZStack {
                                        
                                        Image("onboard_img_1")
                                            .resizable()
                                            .frame(width: 50, height: 50)
                                            .foregroundColor(.gray.opacity(0.4))
                                            .clipShape(Circle())
                                            .overlay(
                                                Circle()
                                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                                            )
                                            
                                    }
                                    
                                    // Placeholder rather than an empty row when
                                    // no name is set — otherwise the card reads
                                    // as broken (avatar, blank space, chevron)
                                    // and gives no hint that it's editable.
                                    // Muted colour marks it as a prompt, not a
                                    // value. Guests reach Profile without ever
                                    // being asked for a name, so this is the
                                    // common state now, not an edge case.
                                    if let name = userProfileStore.displayName?
                                        .trimmingCharacters(in: .whitespacesAndNewlines),
                                       !name.isEmpty {
                                        Text(name)
                                            .font(.manropeMedium(size: 18))
                                            .foregroundColor(.wingmanBlack)
                                    } else {
                                        Text("Add your name")
                                            .font(.manropeMedium(size: 18))
                                            .foregroundColor(Color.wingmanBlack.opacity(0.4))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                                .padding(0)
                                .background(Color.white)
                                .cornerRadius(12)
                                
                            }
                            .buttonStyle(ScalePressStyle())
                            .padding(.horizontal, 20)
                            .padding(.vertical, 28)

                            Divider().background(Color.gray.opacity(0.2))

                            // MARK: - Save Your Progress (guest only)
                            //
                            // Threshold-triggered, not permanent — see
                            // AuthContext.saveProgress. Placed here rather than
                            // in Settings because Settings has no traffic, and
                            // because the thing it protects (the approach log)
                            // is visibly sitting further down this same screen.
                            if authManager.shouldShowGuestAccountPrompt(
                                approachCount: approachService.totalCount
                            ) {
                                SaveProgressBanner(
                                    approachCount: approachService.totalCount,
                                    onTap: { showSaveProgress = true },
                                    onDismiss: {
                                        authManager.markGuestAccountPromptDismissed(
                                            approachCount: approachService.totalCount
                                        )
                                    }
                                )
                                .padding(.horizontal, 20)
                                .padding(.top, 28)
                            }

                            // MARK: - Week Streak Card
                            // Pulls from StreakStore: cache-seeded on init so the card shows
                            // the last-known-good value immediately on entry, refreshed in background.
                            WeekStreakCard(
                                currentStreak: streakStore.currentStreak ?? 0,
                                totalStreak: streakStore.totalCompleted ?? 0,
                                completedDates: streakStore.completedDates
                            )
                                .padding(.horizontal, 20)
                                .padding(.top, 40)
                            
                            // MARK: - Invite Friends Card
                            InviteFriendsCard()
                                .padding(.horizontal, 20)
                                .padding(.top, 40)
                            
                            // MARK: - Confidence Chart
                            //ConfidenceChartCard()
                            //   .padding(.horizontal, 20)
                            //    .padding(.top, 40)
                            
                            // MARK: - Approaches Breakdown
                            // Read directly from the shared service — body re-runs
                            // whenever approaches/totalCount publish a change.
                            ApproachesBreakdownCard(breakdown: approachService.getApproachesBreakdown())
                                .padding(.horizontal, 20)
                                .padding(.top, 40)

                            // MARK: - Approaches Logged Card
                            Group {
                                if approachService.totalCount > 0 {
                                    Button(action: {
                                        showApproachesLogged = true
                                    }) {
                                        ApproachesLoggedCard(count: approachService.totalCount, hasReflections: true)
                                    }
                                    .buttonStyle(ScalePressStyle())
                                } else {
                                    ApproachesLoggedCard(count: approachService.totalCount, hasReflections: false)
                                        .allowsHitTesting(false) // non-interactive when no reflections
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 40)
                            
                            Spacer().frame(height: 100)
                        }
                        .padding(.top, 2)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .scrollToTopTab)) { note in
                        guard (note.object as? Int) == 3 else { return }
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("top", anchor: .top)
                        }
                    }
                    }
                }
            }
            // Remove system nav title and toolbar entirely
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            // Keep sheets
            .sheet(isPresented: $showSettings) {
                SettingsSheet(userName: userProfileStore.displayName ?? "")
                    // SE-class phones (~667pt tall) can't fit a 720pt detent —
                    // fall back to `.large` so the sheet maxes out at the
                    // available screen height. Standard / Max phones keep the
                    // original fixed detent unchanged.
                    .presentationDetents(UIScreen.isSmallPhone ? [.large] : [.height(720)])
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(20)
            }
            // Presented as a sheet, not a route: this is an offer the user can
            // walk away from. A successful link clears `isGuestSession`, which
            // removes the banner on its own; declining records the threshold.
            .sheet(isPresented: $showSaveProgress) {
                NavigationStack {
                    AuthView(
                        mode: .signup,
                        context: .saveProgress,
                        onSkip: {
                            authManager.markGuestAccountPromptDismissed(
                                approachCount: approachService.totalCount
                            )
                            showSaveProgress = false
                        }
                    )
                }
                .appDynamicTypeCeiling()
            }
            .onChange(of: authManager.isGuestSession) { isGuest in
                // Linked successfully from the sheet — close it rather than
                // leaving the user on a screen whose purpose is now satisfied.
                if !isGuest { showSaveProgress = false }
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet(currentName: userProfileStore.displayName ?? "") { newName in
                    // EditProfileSheet writes Supabase + cache itself; this
                    // callback is additionally idempotent via apply(name:) so
                    // the avatar card re-renders immediately on save.
                    UserProfileStore.shared.apply(name: newName)
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(20)
            }
            .fullScreenCover(isPresented: $showApproachesLogged) {
                ApproachesLoggedListView()
                    .appDynamicTypeCeiling()
            }
        }
        .onAppear {
            // Tab entry refreshes each store in the background; view body reads
            // directly from the shared stores, so any write elsewhere (log,
            // edit, delete, daily-practice completion, name change) is already
            // reflected when we arrive.
            if let last = lastRefreshedAt, Date().timeIntervalSince(last) < 5 {
                return
            }
            lastRefreshedAt = Date()

            Task { await loadApproachData() }
            Task { await streakStore.refresh() }
            Task { await userProfileStore.refresh() }
        }
        .postHogScreenView("Profile")
    }

    private func loadApproachData() async {
        // Fetch fresh data from Supabase. The view body reads ApproachService
        // directly, so the re-render happens automatically when fetchApproaches
        // publishes updates — no @State mirroring needed.
        await approachService.fetchApproaches()

        // Keep the legacy UserDefaults mirrors (`total_approaches`,
        // `last_practice_date`) in sync for any other code still reading them.
        await MainActor.run {
            approachService.updateLocalStats()
        }
    }
    
}

// MARK: - Save Progress Banner (guest only)

/// Offers a guest an account, naming the specific thing at risk.
///
/// Deliberately understated — an outline card in the app's existing language
/// rather than a coloured alert. It is an offer, not a warning, and the user has
/// done nothing wrong by not having an account.
private struct SaveProgressBanner: View {
    let approachCount: Int
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    // Pluralised: the first threshold is 1, so the singular case
                    // is the common one, not an edge case.
                    Text(approachCount == 1
                         ? "Save your first approach"
                         : "Save your \(approachCount) approaches")
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(.wingmanBlack)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(approachCount == 1
                         ? "It's on this device only. An account keeps it if you change phones."
                         : "They're on this device only. An account keeps them if you change phones.")
                        .font(.manropeRegular(size: 13))
                        .foregroundColor(Color.wingmanBlack.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.wingmanBlack.opacity(0.4))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ScalePressStyle())
            }

            Button(action: onTap) {
                Text("Create a free account")
                    .font(.manropeSemiBold(size: 14))
                    .foregroundColor(.wingmanWhiteFF)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.wingmanBlack)
                    .cornerRadius(5)
            }
            .buttonStyle(ScalePressStyle())
        }
        .padding(16)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.wingmanBlack.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Week Streak Card
struct WeekStreakCard: View {
    let currentStreak: Int
    let totalStreak: Int
    let completedDates: Set<String>
    
    // Get the days of the current week dynamically
    private var weekDays: [(String, String, Bool)] {
        let calendar = Calendar.current
        let today = Date()
        
        // Find the start of the week (Sunday)
        let weekday = calendar.component(.weekday, from: today)
        let daysFromSunday = weekday - 1
        guard let startOfWeek = calendar.date(byAdding: .day, value: -daysFromSunday, to: today) else {
            return []
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]
        
        var result: [(String, String, Bool)] = []
        for i in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: i, to: startOfWeek) else { continue }
            let dateString = dateFormatter.string(from: date)
            let isCompleted = completedDates.contains(dateString)
            result.append((dayLetters[i], dateString, isCompleted))
        }
        
        return result
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Week days with flames
            HStack(spacing: 0) {
                ForEach(weekDays, id: \.1) { day in
                    VStack(spacing: 4) {
                        Image(day.2 ? "flame_fill_p" : "flame")
                            .resizable()
                            .scaledToFit()
                            .foregroundColor(day.2 ? .wingmanBlack : .gray.opacity(0.3))
                            .frame(width: 17, height: 24)
                        
                        Text(day.0)
                            .font(.manropeMedium(size: 12))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            Divider().background(Color.gray.opacity(0.2))
                .padding(.horizontal, 20)
            
            // Current and Total
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("current")
                        .font(.manropeMedium(size: 12))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 4) {
                        Image("flame_fill_p_s")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundColor(.wingmanBlack)

                        Text("\(currentStreak) days")
                            .font(.manropeMedium(size: 14))
                            .foregroundColor(.wingmanBlack)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("total")
                        .font(.manropeMedium(size: 12))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 4) {
                        Image("flame_fill_p_s")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                            .foregroundColor(.wingmanBlack)
                        Text("\(totalStreak) days")
                            .font(.manropeMedium(size: 14))
                            .foregroundColor(.wingmanBlack)
                    }
                }
            }
            .padding(.leading,20)
            .padding(.trailing,20)
        }
        .padding(.vertical,20)
        .background(Color.white)
        .cornerRadius(5)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.wingmanBlack.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Invite Friends Card
struct InviteFriendsCard: View {
    var body: some View {
        Button(action: {
            shareApp()
        }) {
            HStack() {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Invite Friends")
                        .font(.manropeMedium(size: 18))
                        .foregroundColor(.wingmanBlack)
                    
                    Text("Invite your friends to the community and learn together")
                        .font(.manropeRegular(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.leading)
                        
                        
                        
                }
                .padding(.vertical,20)
                .padding(.leading,20)
                
                Spacer()
                
                // Illustration placeholder
                Image("Invite_Friends")
                    .resizable()
                    .frame(width: 150, height: 150)
                    .foregroundColor(.gray.opacity(0.2))
            }
            
            .background(Color.white)
            .cornerRadius(5)
            .shadow(color: Color.wingmanBlack.opacity(0.05), radius: 8, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(ScalePressStyle())
    }
    
    private func shareApp() {
        let appURL = "https://apps.apple.com/app/wingman" // Replace with actual app URL
        let activityVC = UIActivityViewController(
            activityItems: ["Join me on Wingman! \(appURL)"],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Confidence Chart Card
struct ConfidenceChartCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Confidence Over Time")
                .font(.manropeMedium(size: 12))
                .foregroundColor(.wingmanBlack)
            
            // Simple line chart placeholder
            GeometryReader { geometry in
                Path { path in
                    let points: [CGFloat] = [0.3, 0.25, 0.5, 0.4, 0.6, 0.55, 0.75, 0.7, 0.85, 0.9]
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let stepX = width / CGFloat(points.count - 1)
                    
                    path.move(to: CGPoint(x: 0, y: height * (1 - points[0])))
                    
                    for (index, point) in points.enumerated() {
                        let x = stepX * CGFloat(index)
                        let y = height * (1 - point)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(Color.wingmanBlack, lineWidth: 2)
                
                // Data points
                Path { path in
                    let points: [CGFloat] = [0.3, 0.25, 0.5, 0.4, 0.6, 0.55, 0.75, 0.7, 0.85, 0.9]
                    let width = geometry.size.width
                    let height = geometry.size.height
                    let stepX = width / CGFloat(points.count - 1)
                    
                    for (index, point) in points.enumerated() {
                        let x = stepX * CGFloat(index)
                        let y = height * (1 - point)
                        path.addEllipse(in: CGRect(x: x - 3, y: y - 3, width: 6, height: 6))
                    }
                }
                .fill(Color.wingmanBlack)
            }
            .frame(height: 120)
            .padding(.top, 8)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(5)
        .shadow(color: Color.wingmanBlack.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Approaches Breakdown Card
struct ApproachesBreakdownCard: View {
    let breakdown: [(String, Int, Double)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Approaches Breakdown")
                .font(.manropeMedium(size: 18))
                .foregroundColor(.wingmanBlack)
                .padding(.bottom,5)
            
            if breakdown.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 30))
                        .foregroundColor(.gray.opacity(0.3))
                    
                    Text("No approach data yet")
                        .font(.manropeMedium(size: 14))
                        .foregroundColor(.gray)
                    
                    Text("Start logging approaches to see your breakdown")
                        .font(.manropeRegular(size: 12))
                        .foregroundColor(.gray.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 12) {
                    ForEach(breakdown, id: \.0) { approach in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(approach.0)
                                    .font(.manropeMedium(size: 14))
                                    .foregroundColor(Color.wingmanBlack.opacity(0.7))
                                
                                Spacer()
                                
                                Text("\(approach.1)")
                                    .font(.manropeMedium(size: 14))
                                    .foregroundColor(Color.wingmanBlack.opacity(0.7))
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(height: 8)
                                    
                                    if approach.2 > 0 {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.wingmanBlack)
                                            .frame(width: geometry.size.width * approach.2, height: 8)
                                    }
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(5)
        .shadow(color: Color.wingmanBlack.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Approaches Logged Card
struct ApproachesLoggedCard: View {
    let count: Int
    let hasReflections: Bool
    
    var body: some View {
        VStack{
            HStack {
                Image("feather")
                    .font(.system(size: 18))
                    .foregroundColor(.wingmanBlack)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Approaches logged")
                        .font(.manropeSemiBold(size: 15))
                        .foregroundColor(.wingmanBlack)
                    
                }
                
                Spacer()
                
                HStack(spacing: 0) {
                    // Count pill (always shows, including 0)
                    Text("\(count)")
                        .font(.manropeMedium(size: 18))
                        .foregroundColor(.wingmanBlack)
                        .opacity(0.5)
                        .padding(.horizontal, 2)
                        .background(Color.white)
                        .cornerRadius(5)
                    
                    if hasReflections {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal,20)
            .padding(.top,20)
            .padding(.bottom,1)
            
            
            Text(hasReflections ? "Check your reflections to see insights" : "No reflections yet. Start logging approaches with notes to see your insights")
                .font(.manropeRegular(size: 14))
                .foregroundColor(.gray)

                .frame(maxWidth: .infinity, alignment: .leading) // key line
                .padding(.horizontal,20)
                .padding(.bottom,20)
        }
        .background(Color.white)
        .cornerRadius(5)
        .shadow(color: Color.wingmanBlack.opacity(0.05), radius: 8, x: 0, y: 2)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    ProfileView()
}
