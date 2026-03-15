//
//  PaywallView.swift
//  Wingman
//
//  Created by Adnan Khan on 17/12/2025.
//

import SwiftUI

struct PaywallView: View {

    @StateObject private var viewModel = PaywallViewModel()
    @State private var navigateToReferral = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

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
                        price: "$44.99 per year",
                        weekly: "only $0.96",
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
                        price: "$12.99",
                        weekly: "only $2.29",
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
                    viewModel.continueTapped()
                    navigateToReferral = true
                } label: {
                    Text("Continue")
                        .font(.manropeSemiBold(size: 16))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundColor(.white)
                        .background(Color.black)
                        .cornerRadius(5)
                }
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
                        viewModel.openRestore()
                    } label: {
                        Text("Restore")
                            .font(.manropeMedium(size: 12))
                            .foregroundColor(Color(hex: "6B7280"))
                            .underline()
                    }
                    
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

                NavigationLink("", destination: ReferralView(), isActive: $navigateToReferral)
                    .hidden()
            }
            .background(Color.white)
        }
    }
}

#Preview {
    PaywallView()
}
