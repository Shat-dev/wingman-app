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
                // Daily practice shows the streak as a figure rather than as
                // the "N day streak" line lessons and scenarios get, because
                // this is the surface the streak belongs to — it is the payoff,
                // not a footnote. Same mark and same colour as those screens
                // though: `StreakMark` exists so the glyph cannot drift again.
                //
                // Note this does not come through `CompletionScreen`'s own
                // streak row. That row reads `StreakStore.lastAdvance`, which
                // only `noteActivity` writes, and daily practice moves the
                // streak through `update_daily_practice_streak` instead — so
                // `currentStreak` is passed in and rendered here. One streak on
                // the screen either way.
                HStack(spacing: 10) {
                    StreakMark(size: 29)

                    Text("\(currentStreak)")
                        .font(.manropeMedium(size: 31))
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
