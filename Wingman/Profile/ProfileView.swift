//
//  ProfileView.swift
//  Wingman
//

import SwiftUI
import Combine

struct ProfileView: View {
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showApproachesLogged = false
    @State private var userName = "Shat"
    @State private var approachesCount = 0
    @State private var hasReflections = false
    @State private var approachesBreakdown: [(String, Int, Double)] = []
    @StateObject private var approachService = ApproachService.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        
                        // MARK: - User Profile Card
                        Button(action: {
                            showEditProfile = true
                        }) {
                            HStack(spacing: 12) {
                                // Avatar placeholder
                                ZStack {
                                    Circle()
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.gray.opacity(0.4))
                                }
                                
                                Text(userName)
                                    .font(.manropeRegular(size: 18))
                                    .foregroundColor(.black)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            .padding(16)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        
                        // MARK: - Week Streak Card
                        WeekStreakCard()
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        
                        // MARK: - Invite Friends Card
                        InviteFriendsCard()
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        
                        // MARK: - Confidence Chart
                        ConfidenceChartCard()
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        
                        // MARK: - Approaches Breakdown
                        ApproachesBreakdownCard(breakdown: approachesBreakdown)
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        
                        // MARK: - Approaches Logged Card
                        Button(action: {
                            showApproachesLogged = true
                        }) {
                            ApproachesLoggedCard(count: approachesCount, hasReflections: hasReflections)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        
                        Spacer().frame(height: 100)
                    }
                    .padding(.top, 8)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Profile")
                        .font(.manropeSemiBold(size: 28))
                        .foregroundColor(.black)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.black)
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(userName: userName)
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet(currentName: userName) { newName in
                    userName = newName
                    // TODO: Save to Supabase
                    UserDefaults.standard.set(newName, forKey: "user_name")
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
            loadUserData()
        }
        .refreshable {
            await loadApproachData()
        }
    }
    
    private func loadUserData() {
        // Load user name from UserDefaults or Supabase
        if let savedName = UserDefaults.standard.string(forKey: "user_name") {
            userName = savedName
        }
        
        // Load approach data
        Task {
            await loadApproachData()
        }
    }
    
    private func loadApproachData() async {
        // Fetch fresh data from Supabase
        await approachService.fetchApproaches()
        
        // Update local state with fresh data
        await MainActor.run {
            self.approachesCount = approachService.totalCount
            self.hasReflections = approachService.totalCount > 0
            self.approachesBreakdown = approachService.getApproachesBreakdown()
            
            // Update local stats for other parts of the app
            approachService.updateLocalStats()
        }
    }
}

// MARK: - Week Streak Card
struct WeekStreakCard: View {
    let days = ["T", "W", "T", "F", "S", "S", "M"]
    let completed = [true, true, false, false, false, false, false]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Week days with flames
            HStack(spacing: 0) {
                ForEach(0..<7) { index in
                    VStack(spacing: 4) {
                        Image(systemName: completed[index] ? "flame.fill" : "flame")
                            .font(.system(size: 20))
                            .foregroundColor(completed[index] ? .black : .gray.opacity(0.3))
                        
                        Text(days[index])
                            .font(.manropeRegular(size: 12))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            
            // Current and Total
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("current")
                        .font(.manropeRegular(size: 11))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.black)
                        Text("2 days")
                            .font(.manropeSemiBold(size: 15))
                            .foregroundColor(.black)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text("total")
                        .font(.manropeRegular(size: 11))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.black)
                        Text("69 days")
                            .font(.manropeSemiBold(size: 15))
                            .foregroundColor(.black)
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Invite Friends Card
struct InviteFriendsCard: View {
    var body: some View {
        Button(action: {
            shareApp()
        }) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Invite Friends")
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(.black)
                    
                    Text("Invite your friends to the community and learn together")
                        .font(.manropeRegular(size: 13))
                        .foregroundColor(.gray)
                        .lineSpacing(2)
                }
                
                Spacer()
                
                // Illustration placeholder
                Image(systemName: "person.2")
                    .font(.system(size: 50))
                    .foregroundColor(.gray.opacity(0.2))
            }
            .padding(16)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Confidence Over Time")
                .font(.manropeSemiBold(size: 16))
                .foregroundColor(.black)
            
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
                .stroke(Color.black, lineWidth: 2)
                
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
                .fill(Color.black)
            }
            .frame(height: 120)
            .padding(.top, 8)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Approaches Breakdown Card
struct ApproachesBreakdownCard: View {
    let breakdown: [(String, Int, Double)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Approaches Breakdown")
                .font(.manropeSemiBold(size: 16))
                .foregroundColor(.black)
            
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
                                    .font(.manropeRegular(size: 14))
                                    .foregroundColor(.black)
                                
                                Spacer()
                                
                                Text("\(approach.1)")
                                    .font(.manropeSemiBold(size: 14))
                                    .foregroundColor(.black)
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.1))
                                        .frame(height: 8)
                                    
                                    if approach.2 > 0 {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.black)
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
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Approaches Logged Card
struct ApproachesLoggedCard: View {
    let count: Int
    let hasReflections: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "pencil")
                .font(.system(size: 18))
                .foregroundColor(.black)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Approaches logged")
                    .font(.manropeSemiBold(size: 15))
                    .foregroundColor(.black)
                
                Text(hasReflections ? "Check your reflections to see insights" : "No reflections yet. Start logging approaches with notes to see your insights")
                    .font(.manropeRegular(size: 12))
                    .foregroundColor(.gray)
                    .lineSpacing(2)
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Text("\(count)")
                    .font(.manropeSemiBold(size: 16))
                    .foregroundColor(.black)
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

#Preview {
    ProfileView()
}
