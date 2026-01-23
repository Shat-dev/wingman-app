//
//  PracticeView.swift
//  Wingman
//
//  Created by Adnan Khan on 23/01/2026.
//


//
//  PracticeView.swift
//  Wingman
//
//  Created by Claude on 23/01/2026.
//

import SwiftUI

struct PracticeView: View {
    
    // MARK: - Properties
    @StateObject private var viewModel = PracticeViewModel()
    @State private var navigateToPracticeDetail: Bool = false
    
    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.white
                    .ignoresSafeArea()
                
                // Content
                VStack(spacing: 0) {
                    // Header
                    headerView
                    
                    // Practice List
                    if viewModel.isLoading {
                        loadingView
                    } else if let errorMessage = viewModel.errorMessage {
                        errorView(message: errorMessage)
                    } else {
                        practiceListView
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: $navigateToPracticeDetail) {
                if let practice = viewModel.selectedPractice {
                    PracticeDetailView(practice: practice)
                }
            }
        }
        .task {
            await viewModel.fetchPractices()
        }
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Text("Practice")
                .font(.manropeBold(size: 28))
                .foregroundColor(Color(hex: "#1A1A1A"))
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }
    
    // MARK: - Practice List View
    private var practiceListView: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.practices) { practice in
                    PracticeCardView(practice: practice) {
                        viewModel.selectPractice(practice)
                        navigateToPracticeDetail = true
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100) // Bottom padding for tab bar
        }
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
                    await viewModel.fetchPractices()
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
    PracticeView()
}