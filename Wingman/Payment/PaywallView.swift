//
//  PaywallView.swift
//  Wingman
//
//  Created by Adnan Khan on 17/12/2025.
//

import SwiftUI
import RevenueCat

struct PaywallView: View {

    @StateObject private var viewModel = PaywallViewModel()
    @State private var navigateToReferral = false
    @EnvironmentObject var authManager: AuthManager
    
    // Optional AuthManager for anonymous user purchase tracking
    let authManager_init: AuthManager?
    
    init(authManager: AuthManager? = nil) {
        self.authManager_init = authManager
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    if viewModel.isLoading && viewModel.offerings == nil {
                        // MARK: - Loading State
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            .scaleEffect(1.2)
                        Text("Loading subscription options...")
                            .font(.manropeRegular(size: 16))
                            .foregroundColor(.gray)
                            .padding(.top, 16)
                        Spacer()
                    } else {
                        // MARK: - Carousel
                        TabView(selection: $viewModel.currentPage) {
                            ForEach(viewModel.pages.indices, id: \.self) { index in
                                let page = viewModel.pages[index]
                                
                                VStack(spacing: 0) {
                                    
                                    // Image
                                    Image(page.imageName)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 220)
                                        .padding(.top, 20)
                                        .padding(.bottom, 15)

                                    // Bullets
                                    VStack(alignment: .leading, spacing: 16) {
                                        ForEach(page.bullets, id: \.self) { bullet in
                                            HStack(alignment: .top, spacing: 12) {
                                                Image("check")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.black)
                                                    .frame(width: 16, height: 16)
                                                    .padding(.top, 2)
                                                
                                                Text(bullet)
                                                    .font(.manropeMedium(size: 16))
                                                    .foregroundColor(.black)
                                                    .lineSpacing(2)
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                        }
                                    }
                                    .padding(.horizontal, 17)
                                    
                                    Spacer()
                                }
                                .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .frame(height: 420)
                        
                        // MARK: - Page Indicator
                        HStack(spacing: 8) {
                            ForEach(viewModel.pages.indices, id: \.self) { index in
                                Circle()
                                    .fill(viewModel.currentPage == index ? Color.black : Color.black.opacity(0.2))
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.top, 5)
                        .padding(.bottom, 35)
            
                        // MARK: - Plans
                        VStack(spacing: 12) {
                            
                            // Yearly Plan
                            PlanRow(
                                title: "Yearly Plan",
                                price: viewModel.yearlyPrice,
                                weekly: calculateWeeklyPrice(viewModel.yearlyPackage),
                                weeklySubtitle: "per week",
                                isSelected: viewModel.selectedPlan == .yearly,
                                badgeText: viewModel.selectedPlan == .yearly ? "3-day Free Trial" : nil
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.selectPlan(.yearly)
                                }
                            }
                            .padding(.bottom,10)

                            // Monthly Plan
                            PlanRow(
                                title: "Monthly Plan",
                                price: viewModel.monthlyPrice,
                                weekly: calculateWeeklyPrice(viewModel.monthlyPackage),
                                    weeklySubtitle: "per week",
                                    isSelected: viewModel.selectedPlan == .monthly,
                                    badgeText: viewModel.selectedPlan == .monthly ? "3-day Free Trial" : nil
                            ) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.selectPlan(.monthly)
                                }
                            }
                        }
                        .padding(.horizontal, 20)

                        Spacer()

                        // MARK: - Continue Button
                        Button {
                            Task {
                                let success = await viewModel.continueTapped()
                                if success {
                                    navigateToReferral = true
                                }
                            }
                        } label: {
                            HStack {
                                if viewModel.isPurchasing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                        .padding(.trailing, 8)
                                }
                                Text(viewModel.isPurchasing ? "Processing..." : "Continue")
                                    .font(.manropeSemiBold(size: 16))
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(viewModel.isPurchasing ? 0.7 : 1.0))
                            .cornerRadius(5)
                        }
                        .disabled(viewModel.isPurchasing)
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 16)
                        
                        // MARK: - Footer Links
                        HStack(spacing: 0) {
                            Button {
                                viewModel.openPrivacy()
                            } label: {
                                Text("Privacy")
                                    .font(.manropeMedium(size: 12))
                                    .foregroundColor(Color(hex: "6B7280"))
                                    .underline()
                            }
                            
                            Spacer()
                            
                            Button {
                                Task {
                                    await viewModel.openRestore()
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    if viewModel.isLoading && !viewModel.isPurchasing {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle())
                                            .scaleEffect(0.6)
                                    }
                                    Text("Restore")
                                        .font(.manropeMedium(size: 12))
                                        .foregroundColor(Color(hex: "6B7280"))
                                        .underline()
                                }
                            }
                            .disabled(viewModel.isLoading)
                            
                            Spacer()
                            
                            Button {
                                viewModel.openTerms()
                            } label: {
                                Text("Terms")
                                    .font(.manropeMedium(size: 12))
                                    .foregroundColor(Color(hex: "6B7280"))
                                    .underline()
                            }
                        }
                        .padding(.horizontal, 60)
                        .padding(.bottom, 16)
                    }
                }
                .background(Color.white)
            }
        }
        .navigationDestination(isPresented: $navigateToReferral) {
            ReferralView()
        }
        .alert("Error", isPresented: $viewModel.showAlert) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            Text(viewModel.error ?? "An error occurred")
        }
        .onAppear {
            // Set AuthManager reference for anonymous user purchase tracking
            let authMgr = authManager_init ?? authManager
            viewModel.authManager = authMgr
            
            // If user is returning to paywall due to subscription expiry,
            // refresh offerings and reset UI state
            print("📱 PaywallView appeared")
            viewModel.loadOfferings()
            viewModel.currentPage = 0
            viewModel.selectPlan(.yearly)
        }
        .onDisappear {
            print("📱 PaywallView disappeared")
        }
    }
    
    // MARK: - Helper Methods
    private func calculateWeeklyPrice(_ package: Package?) -> String {
        guard let package = package else { return "N/A" }
        
        let price = package.storeProduct.price
        let period = package.storeProduct.subscriptionPeriod
        
        // Calculate weekly price based on subscription period
        let weeklyPrice: Decimal
        if period?.unit == .year {
            weeklyPrice = price / 52 // 52 weeks in a year
        } else if period?.unit == .month {
            weeklyPrice = price / 4.33 // ~4.33 weeks in a month
        } else {
            weeklyPrice = price
        }
        
        // Use the same formatter configuration as the original price string
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 2
        formatter.locale = Locale.current
        
        return "only " + (formatter.string(from: weeklyPrice as NSNumber) ?? "$0.00")
    }
}

#Preview {
    PaywallView()
}
