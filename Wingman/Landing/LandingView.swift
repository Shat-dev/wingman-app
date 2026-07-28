//
//  OnboardingView.swift
//  Wingman
//
//  Created by Adnan Khan on 29/11/2025.
//

import SwiftUI
import PostHog

struct LandingView: View {
    @StateObject private var viewModel = LandingViewModel()
    @EnvironmentObject var authManager: AuthManager

    @State private var navigateToSignup = false
    @State private var navigateToLogin = false
    @State private var navigateToOnboarding = false

    // Carousel heights that scale with Dynamic Type so the heading/description
    // (see `.fixedSize` below) get more room as text grows instead of being
    // truncated by the fixed-height paging TabView. Equal the originals
    // (520 / 400) at the default text size — no change until the app-wide
    // ceiling is raised above `.large`.
    @ScaledMetric(relativeTo: .body) private var carouselHeight: CGFloat = 520
    @ScaledMetric(relativeTo: .body) private var carouselHeightSmall: CGFloat = 400

    var body: some View {
        NavigationStack {
            VStack {

                // MARK: - Carousel
                TabView(selection: $viewModel.currentPage) {
                    ForEach(viewModel.pages.indices, id: \.self) { index in
                        let page = viewModel.pages[index]

                        VStack(spacing: 14) {

                            // MARK: - Heading
                            Text(page.title)
                                .font(.manropeSemiBold(size: 32))
                                .foregroundColor(.wingmanBlack)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .fixedSize(horizontal: false, vertical: true)

                            // MARK: - Description
                            Text(page.description)
                                .font(.manropeRegular(size: 16))
                                .foregroundColor(Color.wingmanBlack.opacity(0.5))
                                .multilineTextAlignment(.leading)
                                .lineSpacing(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 20)
                                .fixedSize(horizontal: false, vertical: true)

                            // MARK: - Image
                            Image(page.imageName)
                                .resizable()
                                .scaledToFit()
                                // SE-only: shrink the hero image so the
                                // carousel can fit in the reduced frame
                                // height below. Standard / Max phones keep
                                // the original 320pt image.
                                .frame(height: UIScreen.isSmallPhone ? 200 : 320)
                                .padding(.top, 10)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                // SE-only: reduce carousel height so that the CTA buttons
                // below remain visible on ~667pt-tall screens. Standard /
                // Max phones are untouched at 520pt.
                .frame(height: UIScreen.isSmallPhone ? carouselHeightSmall : carouselHeight)



                // MARK: - CTA Buttons
                VStack(spacing: 20) {

                    // MARK: - Page Indicator
                    HStack(spacing: 6) {
                        ForEach(viewModel.pages.indices, id: \.self) { index in
                            Circle()
                                .fill(viewModel.currentPage == index ? Color.wingmanBlack : Color.wingmanBlack.opacity(0.25))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.bottom, 5)

                    // Create Account
                    Button {
                        HapticManager.shared.mediumImpact()
                        navigateToSignup = true
                    } label: {
                        Text("Create Account")
                            .font(.manropeSemiBold(size: 16))
                            .foregroundColor(.wingmanBlack)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.wingmanBlack.opacity(0.5), lineWidth: 1)
                            )
                            .shadow(color: Color.wingmanBlack.opacity(0.06), radius: 5, x: 0, y: 2)
                    }
                    .navigationDestination(isPresented: $navigateToSignup) {
                        AuthView(mode: .signup)
                    }

                    // Log In
                    Button {
                        HapticManager.shared.mediumImpact()
                        navigateToLogin = true
                    }
                    label: {
                        Text("Log In")
                            .font(.manropeSemiBold(size: 16))
                            .foregroundColor(.wingmanWhiteFF)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.wingmanBlack)
                            .cornerRadius(5)
                    }
                    .navigationDestination(isPresented: $navigateToLogin) {
                        AuthView(mode: .login)
                    }

                    // Skip
                    Button {
                        log("🔘 Skip for now button tapped")
                        authManager.startAnonymousOnboarding()
                        navigateToOnboarding = true
                    } label: {
                        Text("Skip for now")
                            .font(.manropeSemiBold(size: 16))
                            .foregroundColor(Color.wingmanBlack)
                            .underline()
                            
                    }
                    .navigationDestination(isPresented: $navigateToOnboarding) {
                        OnboardingView(showLanding: $navigateToOnboarding)
                    }
                }
                .padding(.horizontal, 20)

                Spacer().frame(height: 10)
            }
            // Note: Dynamic Type is clamped app-wide at the root
            // (WingmanApp → RootView), which covers this screen, so no
            // per-screen clamp is needed here.
        }
        .onChange(of: navigateToOnboarding) { newValue in
            log("📊 LandingView: navigateToOnboarding changed to: \(newValue)")
        }
        .postHogScreenView("Landing")
    }
}


#Preview {
    LandingView()
        .environmentObject(AuthManager())
}
