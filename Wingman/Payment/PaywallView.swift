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
            VStack {

                // MARK: - Carousel
                TabView(selection: $viewModel.currentPage) {
                    ForEach(viewModel.pages.indices, id: \.self) { index in
                        let page = viewModel.pages[index]

                        VStack(spacing: 20) {

                            Image(page.imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 260)

                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(page.bullets, id: \.self) { bullet in
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "checkmark")
                                        Text(bullet)
                                    }
                                    .font(.subheadline)
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 420)

                

                // MARK: - Plans
                VStack(spacing: 12) {
                    
                    // MARK: - Page Indicator
                    HStack(spacing: 6) {
                        ForEach(viewModel.pages.indices, id: \.self) { index in
                            Circle()
                                .fill(viewModel.currentPage == index ? .black : .black.opacity(0.25))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.bottom, 10)

                    PlanRow(
                        title: "Yearly Plan",
                        price: "$44.99 per year",
                        weekly: "only $0.96 per week",
                        isSelected: viewModel.selectedPlan == .yearly
                    ) {
                        viewModel.selectPlan(.yearly)
                    }

                    PlanRow(
                        title: "Monthly Plan",
                        price: "$12.99",
                        weekly: "only $2.29 per week",
                        isSelected: viewModel.selectedPlan == .monthly
                    ) {
                        viewModel.selectPlan(.monthly)
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                // MARK: - Continue
                Button {
                    viewModel.continueTapped()
                    navigateToReferral = true
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.black)
                        .cornerRadius(5)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                NavigationLink("", destination: ReferralView(), isActive: $navigateToReferral)
            }
        }
    }
}


#Preview {
    PaywallView()
}
