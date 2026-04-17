//
//  ProfileView.swift
//  Wingman
//

import SwiftUI
import Combine
import Supabase

struct ProfileView: View {
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showApproachesLogged = false
    // Bound directly to the shared stores so any mutation elsewhere (logging,
    // editing, deleting an approach, completing daily practice, editing name)
    // re-renders the card instantly without waiting for onAppear/pull-to-refresh.
    @StateObject private var approachService = ApproachService.shared
    @StateObject private var streakStore = StreakStore.shared
    @StateObject private var userProfileStore = UserProfileStore.shared
    
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
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                    
                    // Divider if you want a visual separation (optional)
                    // Divider().background(Color.gray.opacity(0.2))
                    
                    // MARK: - Scrollable Content
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            
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
                                    
                                    Text(userProfileStore.displayName ?? "")
                                        .font(.manropeMedium(size: 18))
                                        .foregroundColor(.wingmanBlack)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                                .padding(0)
                                .background(Color.white)
                                .cornerRadius(12)
                                
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 28)

                            Divider().background(Color.gray.opacity(0.2))
                            
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
                                    .buttonStyle(.plain)
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
                }
            }
            // Remove system nav title and toolbar entirely
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
            // Keep sheets
            .sheet(isPresented: $showSettings) {
                SettingsSheet(userName: userProfileStore.displayName ?? "")
                    .presentationDetents([.height(630)])
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(20)
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
            }
        }
        .onAppear {
            // Tab entry refreshes each store in the background; view body reads
            // directly from the shared stores, so any write elsewhere (log,
            // edit, delete, daily-practice completion, name change) is already
            // reflected when we arrive.
            Task { await loadApproachData() }
            Task { await streakStore.refresh() }
            Task { await userProfileStore.refresh() }
        }
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
