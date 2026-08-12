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
    @ObservedObject private var xpStore = XPStore.shared

    let currentStreak: Int
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

                // MARK: - XP Earned
                // Renders only once the server confirms the award, so it never
                // claims XP a replay did not grant. Takes no vertical space
                // until then.
                XPAwardBadge(award: xpStore.lastAward)
                    .padding(.bottom, 20)

                Spacer()
                
                // MARK: - Continue Button
                Button(action: {
                    HapticManager.shared.tapStrong()
                    log("🎯 Continue button tapped - navigating to HomeView")

                    tabBarVisibility.showTabBar()

                    log("📡 Posting NavigateToHomeView notification")
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToHomeView"),
                        object: nil
                    )

                    log("🏠 Dismissing daily practice to return to HomeView")
                    dismissDailyPractice()
                }) {
                    Text("Continue")
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.wingmanBlack)
                        .cornerRadius(5)
                }
                .buttonStyle(ScalePressStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationBarHidden(true)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            log("🎯 QuestionsCompleteView appeared - hiding tab bar")
            tabBarVisibility.hideTabBar()
        }
        .onDisappear {
            log("🎯 QuestionsCompleteView disappeared - ensuring tab bar is shown")
            tabBarVisibility.showTabBar()
        }
    }
}

#Preview {
    QuestionsCompleteView(
        currentStreak: 4,
        dismissDailyPractice: {}
    )
}
