//
//  MainTabView.swift
//  Wingman
//
//  Created by Adnan Khan on 22/12/2025.
//


//
//  MainTabView.swift
//  Wingman
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(0)
                
                CoursesView()
                    .tag(1)
                
                PracticeView()
                    .tag(2)
                
                ProfileView()
                    .tag(3)
            }
            .tabViewStyle(.automatic)
            
            // Custom Tab Bar
            CustomTabBar(selectedTab: $selectedTab)
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Custom Tab Bar
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "house.fill",
                title: "Home",
                isSelected: selectedTab == 0
            ) {
                selectedTab = 0
            }
            
            TabBarButton(
                icon: "play.rectangle.fill",
                title: "Courses",
                isSelected: selectedTab == 1
            ) {
                selectedTab = 1
            }
            
            TabBarButton(
                icon: "chart.bar.fill",
                title: "Practice",
                isSelected: selectedTab == 2
            ) {
                selectedTab = 2
            }
            
            TabBarButton(
                icon: "person.fill",
                title: "Profile",
                isSelected: selectedTab == 3
            ) {
                selectedTab = 3
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(
            Color.white
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
        )
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Tab Bar Button
struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .black : .gray.opacity(0.5))
                
                Text(title)
                    .font(.manropeRegular(size: 11))
                    .foregroundColor(isSelected ? .black : .gray.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager())
}