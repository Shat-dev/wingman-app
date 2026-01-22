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

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content (keeps your existing views)
            TabView(selection: $selectedTab) {
                HomeView()
                    .tag(0)

                CoursesView()
                    .tag(1)

                DailyPracticeView()
                    .tag(2)

                ProfileView()
                    .tag(3)
            }
            .tabViewStyle(.automatic)

            // Custom Tab Bar (blurred / frosted)
            CustomTabBar(selectedTab: $selectedTab)
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
                icon: "house.fill",
                title: "Home",
                isSelected: selectedTab == 0
            ) { selectedTab = 0 }

            TabBarButton(
                icon: "play.rectangle.fill",
                title: "Courses",
                isSelected: selectedTab == 1
            ) { selectedTab = 1 }

            TabBarButton(
                icon: "chart.bar.fill",
                title: "Practice",
                isSelected: selectedTab == 2
            ) { selectedTab = 2 }

            TabBarButton(
                icon: "person.fill",
                title: "Profile",
                isSelected: selectedTab == 3
            ) { selectedTab = 3 }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 0)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                // Native system blur (frosted glass)
                VisualBlurView(style: .systemUltraThinMaterialLight)
                    .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))

                // Slight white overlay to tune brightness so it matches the screenshot
                RoundedRectangle(cornerRadius: 0, style: .continuous)
                    .fill(Color.white.opacity(0.06))

                // Fine top stroke (separates bar from content)
                RoundedRectangle(cornerRadius: 0, style: .continuous)
                    .stroke(Color.black.opacity(0.06), lineWidth: 0.5)
                    .blendMode(.normal)
            }
        )
        .overlay(
            // Very faint outer border to match design
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .stroke(Color.black.opacity(0.04), lineWidth: 0.6)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 12, x: 0, y: -6)
        .clipShape(RoundedRectangle(cornerRadius: 0, style: .continuous))
        .padding(.horizontal, 0)
        .ignoresSafeArea(edges: .bottom)
    }

    private func bottomPadding() -> CGFloat {
        // Keep the tabbar comfortably above the home indicator
        let bottomSafe = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .safeAreaInsets.bottom ?? 0

        // tuned to visually match the screenshot padding
        return bottomSafe > 0 ? (8 ) : 0
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
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .black : Color.gray.opacity(0.5))
                    .frame(height: 24)

                // If you use Manrope font extension in your project, replace with:
                // .font(isSelected ? .manropeSemiBold(size: 11) : .manropeRegular(size: 11))
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .black : Color.gray.opacity(0.5))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
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
