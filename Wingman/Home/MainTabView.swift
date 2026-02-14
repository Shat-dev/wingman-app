//
//  MainTabView.swift
//  Wingman
//
//  Created by Adnan Khan on 22/12/2025.
//

// MainTabView.swift
// Pixel-perfect blurred bottom tab bar
// Keeps the same type / method names: MainTabView, CustomTabBar, TabBarButton

import SwiftUI
import UIKit

struct MainTabView: View {
    @State private var selectedTab = 0
    @StateObject private var coursesRouter = CoursesRouter()
    @StateObject private var tabBarVisibility = TabBarVisibilityManager()

    var body: some View {

        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView(selectedTab: $selectedTab)
                    .environmentObject(coursesRouter)
                    .environmentObject(tabBarVisibility)
                    .tag(0)

                CoursesView()
                    .environmentObject(coursesRouter)
                    .environmentObject(tabBarVisibility)
                    .tag(1)

                PracticeView()
                    .environmentObject(tabBarVisibility)
                    .tag(2)

                ProfileView()
                    .environmentObject(tabBarVisibility)
                    .tag(3)
            }
            .tabViewStyle(.automatic)

            if tabBarVisibility.isVisible {
                CustomTabBar(selectedTab: $selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - Custom Tab Bar (keeps same name)
struct CustomTabBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "home",
                title: "Home",
                isSelected: selectedTab == 0
            ) { selectedTab = 0 }

            TabBarButton(
                icon: "map",
                title: "Courses",
                isSelected: selectedTab == 1
            ) { selectedTab = 1 }

            TabBarButton(
                icon: "calendar",
                title: "Schedules",
                isSelected: selectedTab == 2
            ) { selectedTab = 2 }

            TabBarButton(
                icon: "user",
                title: "Profile",
                isSelected: selectedTab == 3
            ) { selectedTab = 3 }
        }
        .padding(.horizontal, 0)
        .padding(.top, 12)
        .padding(.bottom, bottomPadding())
        .frame(maxWidth: .infinity)
        .background(
            Color(red: 0.96, green: 0.96, blue: 0.96) // Light gray background matching the image
        )
        .ignoresSafeArea(edges: .bottom)
    }

    private func bottomPadding() -> CGFloat {
        // Keep the tabbar comfortably above the home indicator
        let bottomSafe = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .safeAreaInsets.bottom ?? 0

        return bottomSafe > 0 ? 2 : 8
    }
}

// MARK: - Tab Bar Button (keeps same name & signature)
struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(isSelected ? .black : Color(red: 0.6, green: 0.6, blue: 0.6))

                Text(title)
                    .font(.manropeMedium(size: 10))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.top,8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - UIKit Blur wrapper: keeps a native appearance
struct VisualBlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style

    init(style: UIBlurEffect.Style = .systemUltraThinMaterialLight) {
        self.style = style
    }

    func makeUIView(context: Context) -> UIVisualEffectView {
        let blur = UIBlurEffect(style: style)
        let view = UIVisualEffectView(effect: blur)
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

// MARK: - Previews
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MainTabView()
                .previewDevice("iPhone 14 Pro")
                .previewDisplayName("iPhone 14 Pro - Light")

            MainTabView()
                .preferredColorScheme(.dark)
                .previewDevice("iPhone 14 Pro")
                .previewDisplayName("iPhone 14 Pro - Dark")
        }
    }
}
