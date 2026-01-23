//
//  PracticeDetailView.swift
//  Wingman
//
//  Created by Claude on 23/01/2026.
//

import SwiftUI

struct PracticeDetailView: View {
    
    // MARK: - Properties
    @StateObject private var viewModel: PracticeDetailViewModel
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Initialization
    init(practice: Practice) {
        _viewModel = StateObject(wrappedValue: PracticeDetailViewModel(practice: practice))
    }
    
    // MARK: - Body
    var body: some View {
        ZStack {
            // Background
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Navigation Bar
                navigationBar
                
                if viewModel.isLoading {
                    loadingView
                } else if let errorMessage = viewModel.errorMessage {
                    errorView(message: errorMessage)
                } else {
                    // Content
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            // Hero Image
                            heroImageView
                            
                            // Practice Info
                            practiceInfoView
                            
                            // Content
                            if let detail = viewModel.practiceDetail {
                                contentView(detail: detail)
                            }
                            
                            // Start Button
                            startButton
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.fetchPracticeDetail()
        }
    }
    
    // MARK: - Navigation Bar
    private var navigationBar: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                    .frame(width: 44, height: 44)
            }
            
            Spacer()
            
            Text("Practice")
                .font(.manropeSemiBold(size: 17))
                .foregroundColor(Color(hex: "#1A1A1A"))
            
            Spacer()
            
            // Placeholder for alignment
            Color.clear
                .frame(width: 44, height: 44)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
    
    // MARK: - Hero Image
    private var heroImageView: some View {
        Image(viewModel.practice.imageUrl)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .frame(height: 200)
            .background(Color(hex: "#F5F5F5"))
            .cornerRadius(16)
    }
    
    // MARK: - Practice Info
    private var practiceInfoView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            Text(viewModel.practice.title)
                .font(.manropeBold(size: 24))
                .foregroundColor(Color(hex: "#1A1A1A"))
            
            // Daily Practice Count
            HStack(spacing: 6) {
                Text("🔥")
                    .font(.system(size: 14))
                
                Text("\(viewModel.practice.dailyPracticeCount) Daily Practice")
                    .font(.manropeMedium(size: 14))
                    .foregroundColor(Color(hex: "#666666"))
            }
            
            // Summary
            Text(viewModel.practice.summary)
                .font(.manropeRegular(size: 15))
                .foregroundColor(Color(hex: "#666666"))
                .lineSpacing(4)
        }
    }
    
    // MARK: - Content View
    private func contentView(detail: PracticeDetail) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            // Duration
            HStack(spacing: 8) {
                Image(systemName: "clock")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(hex: "#666666"))
                
                Text("\(detail.duration) minutes")
                    .font(.manropeMedium(size: 14))
                    .foregroundColor(Color(hex: "#666666"))
            }
            
            // Divider
            Rectangle()
                .fill(Color(hex: "#E5E5E5"))
                .frame(height: 1)
            
            // Content
            Text(detail.content)
                .font(.manropeRegular(size: 15))
                .foregroundColor(Color(hex: "#333333"))
                .lineSpacing(6)
            
            // Steps
            if !detail.steps.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Steps")
                        .font(.manropeSemiBold(size: 18))
                        .foregroundColor(Color(hex: "#1A1A1A"))
                    
                    ForEach(detail.steps.sorted(by: { $0.order < $1.order })) { step in
                        stepRow(step: step)
                    }
                }
            }
        }
    }
    
    // MARK: - Step Row
    private func stepRow(step: PracticeStep) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Step Number
            Text("\(step.order)")
                .font(.manropeSemiBold(size: 14))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color(hex: "#1A1A1A"))
                .clipShape(Circle())
            
            // Step Content
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.manropeSemiBold(size: 15))
                    .foregroundColor(Color(hex: "#1A1A1A"))
                
                Text(step.description)
                    .font(.manropeRegular(size: 14))
                    .foregroundColor(Color(hex: "#666666"))
            }
        }
    }
    
    // MARK: - Start Button
    private var startButton: some View {
        Button(action: {
            viewModel.startPractice()
        }) {
            Text("Start Practice")
                .font(.manropeSemiBold(size: 16))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color(hex: "#1A1A1A"))
                .cornerRadius(12)
        }
        .padding(.top, 16)
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "#1A1A1A")))
                .scaleEffect(1.2)
            Spacer()
        }
    }
    
    // MARK: - Error View
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "#999999"))
            
            Text(message)
                .font(.manropeMedium(size: 14))
                .foregroundColor(Color(hex: "#666666"))
                .multilineTextAlignment(.center)
            
            Button(action: {
                Task {
                    await viewModel.fetchPracticeDetail()
                }
            }) {
                Text("Try Again")
                    .font(.manropeSemiBold(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#1A1A1A"))
                    .cornerRadius(8)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Preview
#Preview {
    PracticeDetailView(practice: Practice.mockData[0])
}
