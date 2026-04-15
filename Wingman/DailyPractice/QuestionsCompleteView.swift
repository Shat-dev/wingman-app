//
//  QuestionsCompleteView.swift
//  Wingman
//
//  Adnan Khan on 09/03/2026.
//

import SwiftUI

struct QuestionsCompleteView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var tabBarVisibility: TabBarVisibilityManager
    
    let currentStreak: Int
    @Binding var showCompletionView: Bool
    let dismissDailyPractice: () -> Void
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // MARK: - Checkmark Icon
                ZStack {
                    Image("checklist")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 291, height: 291)
                        .clipped()
                        .allowsHitTesting(false)
                }
                .padding(.bottom, 5)
                
                // MARK: - Title
                Text("Daily Practice Complete!")
                    .font(.manropeSemiBold(size: 24))
                    .foregroundColor(.wingmanBlack)
                    .kerning(-0.3)
                    .padding(.bottom, 30)
                
                // MARK: - Streak Section
                HStack(spacing: 8) {
                    Image("flame_fill_p")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 22)
                    
                    Text("\(currentStreak)")
                        .font(.manropeMedium(size: 24))
                        .foregroundColor(.wingmanBlack)
                }
                .padding(.bottom, 20)
                
                Spacer()
                
                // MARK: - Continue Button
                Button(action: {
                    HapticManager.shared.mediumImpact()
                    print("🎯 Continue button tapped - navigating to HomeView")
                    
                    // 1. Show tab bar immediately
                    print("📱 Explicitly showing tab bar before navigation")
                    tabBarVisibility.showTabBar()
                    
                    // 2. Hide this completion view
                    showCompletionView = false
                    
                    // 3. Navigate to Home tab via notification with slight delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        print("📡 Posting NavigateToHomeView notification")
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NavigateToHomeView"),
                            object: nil
                        )
                    }
                    
                    // 4. Dismiss this view with slight delay to ensure proper tab bar visibility
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        print("🏠 Dismissing daily practice to return to HomeView")
                        dismissDailyPractice()
                    }
                }) {
                    Text("Continue")
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.wingmanBlack)
                        .cornerRadius(5)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            print("🎯 QuestionsCompleteView appeared - hiding tab bar")
            tabBarVisibility.hideTabBar()
        }
        .onDisappear {
            print("🎯 QuestionsCompleteView disappeared - ensuring tab bar is shown")
            tabBarVisibility.showTabBar()
        }
    }
}

#Preview {
    QuestionsCompleteView(
        currentStreak: 4,
        showCompletionView: .constant(true),
        dismissDailyPractice: {}
    )
}
