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
                let _ = print("🏠 MainTabView: Tab bar is VISIBLE - showing CustomTabBar")
                CustomTabBar(selectedTab: $selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                let _ = print("🏠 MainTabView: Tab bar is HIDDEN - CustomTabBar not shown")
            }
        }
        .ignoresSafeArea(.keyboard)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToHomeView"))) { _ in
            print("📱 MainTabView: Received NavigateToHomeView notification - switching to Home tab")
            selectedTab = 0
        }
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
            ) { HapticManager.shared.lightImpact(); selectedTab = 0 }

            TabBarButton(
                icon: "map",
                title: "Courses",
                isSelected: selectedTab == 1
            ) { HapticManager.shared.lightImpact(); selectedTab = 1 }

            TabBarButton(
                icon: "calendar",
                title: "Scenarios",
                isSelected: selectedTab == 2
            ) { HapticManager.shared.lightImpact(); selectedTab = 2 }

            TabBarButton(
                icon: "user",
                title: "Profile",
                isSelected: selectedTab == 3
            ) { HapticManager.shared.lightImpact(); selectedTab = 3 }
        }
        .padding(.horizontal, 0)
        .padding(.top, 17) // Reduced from 17 to 12
        .padding(.bottom, -5)
        .frame(maxWidth: .infinity)
        .background(
            CompatibleGlassBackground()
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 10,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 10,
                    style: .continuous
                ))
                .ignoresSafeArea(edges: .bottom)
            
        )
        .overlay(alignment: .top) {
            // Top border that follows the rounded shape
            UnevenRoundedRectangle(
                topLeadingRadius: 10,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 10,
                style: .continuous
            )
            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            .mask(
                // Only show the top part of the stroke
                Rectangle()
                    .frame(height: 15) // Just enough to capture the rounded corners
                    .frame(maxHeight: .infinity, alignment: .top)
            )
        }
    }

    private func bottomPadding() -> CGFloat {
        // Keep the tabbar comfortably above the home indicator
        let bottomSafe = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .safeAreaInsets.bottom ?? 0

        return bottomSafe > 0 ? 0 : 2
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
            VStack() { // Reduced spacing from 6 to 2
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(isSelected ? .black : Color(red: 0.6, green: 0.6, blue: 0.6))

                Text(title)
                    .font(.manropeMedium(size: 10))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .fixedSize() // Prevents text from taking extra space
            }
            .frame(maxWidth: .infinity)
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

// MARK: - Compatible Glass Background
struct CompatibleGlassBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        let visualEffectView = UIVisualEffectView(effect: blurEffect)
        
        // Add a subtle tint for the glass appearance
        let tintView = UIView()
        tintView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        tintView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.contentView.addSubview(tintView)
        
        NSLayoutConstraint.activate([
            tintView.topAnchor.constraint(equalTo: visualEffectView.contentView.topAnchor),
            tintView.leadingAnchor.constraint(equalTo: visualEffectView.contentView.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: visualEffectView.contentView.trailingAnchor),
            tintView.bottomAnchor.constraint(equalTo: visualEffectView.contentView.bottomAnchor)
        ])
        
        return visualEffectView
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        // Update if needed
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
