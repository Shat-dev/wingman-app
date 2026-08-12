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
    let dismissDailyPractice: () -> Void

    var body: some View {
        CompletionScreen(
            title: "Daily practice complete.",
            // Daily practice is awarded once per local day, so the date is the
            // id. Same string `DailyPracticeViewModel` passes to `award`.
            expectedSourceId: XPLocalDate.today(),
            onContinue: {
                // Unchanged from before the shared component: the tab bar has
                // to come back and Home has to be told, or the user lands on a
                // chrome-less screen.
                log("🎯 Continue button tapped - navigating to HomeView")

                tabBarVisibility.showTabBar()

                log("📡 Posting NavigateToHomeView notification")
                NotificationCenter.default.post(
                    name: NSNotification.Name("NavigateToHomeView"),
                    object: nil
                )

                log("🏠 Dismissing daily practice to return to HomeView")
                dismissDailyPractice()
            },
            detail: {
                // The streak stays. Daily practice is the only surface where it
                // is meaningful today — lessons and scenarios do not touch it,
                // so showing it there would imply a link that does not exist.
                HStack(spacing: 8) {
                    Image("flame_fill_p")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 22)

                    Text("\(currentStreak)")
                        .font(.manropeMedium(size: 24))
                        .foregroundColor(.wingmanBlack)
                }
            }
        )
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
    .environmentObject(TabBarVisibilityManager())
}
