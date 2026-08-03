//
//  MainTabView.swift
//  Wingman
//
//  Created by Adnan Khan on 22/12/2025.
//

// MainTabView.swift
// Pixel-perfect blurred bottom tab bar
// Keeps the same type / method names: MainTabView, CustomTabBar, TabBarButton

import SwiftUI
import UIKit

extension Notification.Name {
    static let scrollToTopTab = Notification.Name("ScrollToTopTab")
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var coursesRouter = CoursesRouter()
    @StateObject private var tabBarVisibility = TabBarVisibilityManager()

    /// Owns the first-run walkthrough script. Held here, beside the other two
    /// shared objects, so it survives tab switches and navigation pushes — the
    /// script spans all of them.
    ///
    /// Dormant until something calls `start(...)`, which nothing does yet: the
    /// walkthrough overlay (W5) is what activates it. Injected into all four tabs
    /// now so the surfaces that feed it are already wired when it wakes up.
    @StateObject private var walkthrough = WalkthroughCoordinator()

    var body: some View {

        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                HomeView(selectedTab: $selectedTab)
                    .environmentObject(coursesRouter)
                    .environmentObject(tabBarVisibility)
                    .environmentObject(walkthrough)
                    .tag(0)

                CoursesView()
                    .environmentObject(coursesRouter)
                    .environmentObject(tabBarVisibility)
                    .environmentObject(walkthrough)
                    .tag(1)

                PracticeView()
                    .environmentObject(tabBarVisibility)
                    .environmentObject(walkthrough)
                    .tag(2)

                ProfileView()
                    .environmentObject(tabBarVisibility)
                    .environmentObject(walkthrough)
                    .tag(3)
            }
            .tabViewStyle(.automatic)

            if tabBarVisibility.isVisible {
                let _ = log("🏠 MainTabView: Tab bar is VISIBLE - showing CustomTabBar")
                CustomTabBar(selectedTab: $selectedTab)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    // Locked for the duration of the script. The scenario beat
                    // shows no card at all — the pulsing card is the entire
                    // instruction — so wandering off that screen would leave
                    // the user with nothing telling them what to do. The
                    // coordinator drives tabs by writing `selectedTab`
                    // directly, so it is unaffected by this.
                    //
                    // Disabled only, never dimmed. `CustomTabBar` is drawn on
                    // top of the TabView's OWN tab bar, which is not hidden on
                    // any of the four tab roots — so any transparency here
                    // reveals the system bar underneath, selection pill
                    // included, and the whole navbar appears to change design
                    // mid-walkthrough.
                    .disabled(walkthrough.isRunning)
            } else {
                let _ = log("🏠 MainTabView: Tab bar is HIDDEN - CustomTabBar not shown")
            }

            // First-run walkthrough, topmost so it sits over the tab bar too.
            //
            // Gated on `tabBarVisibility.isVisible` because PracticeGame and
            // LessonView are pushed *inside* the TabView and hide the tab bar
            // on appear — without this the card would draw on top of the
            // scenario the user was just told to play.
            if walkthrough.isRunning && tabBarVisibility.isVisible {
                WalkthroughOverlayView()
                    .environmentObject(walkthrough)
            }
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            // The only activator. Both conditions are suppression layer 1: a
            // user who completed the demo (or was suppressed out of it) carries
            // `hasCompletedFreeDemo`, and a subscriber never reaches RootView's
            // demo branch at all. Idempotent — `start` no-ops unless dormant.
            walkthrough.start(
                hasCompletedFreeDemo: authManager.hasCompletedFreeDemo,
                hasActiveSubscription: authManager.hasActiveSubscription
            )

            // Land on Courses if the walkthrough just handed off there, so the
            // lesson it promised is where the user was left rather than two
            // taps away. One-shot — consumed here.
            if authManager.pendingCoursesHandoff {
                authManager.pendingCoursesHandoff = false
                log("🎬 MainTabView: opening on Courses after walkthrough handoff")
                selectedTab = WalkthroughCoordinator.Tab.courses.rawValue
            }
        }
        // Backstop for a script that ends because the route changed under it —
        // in practice a subscription resolving mid-walkthrough, which moves
        // RootView from branch 4b to 4a and takes this view (and the
        // coordinator) with it.
        //
        // `onDisappear` rather than `onChange(of: hasActiveSubscription)`
        // because that change and RootView's branch swap happen in the same
        // update: the parent can remove this view before its `onChange` is
        // ever delivered. Removal, by contrast, is exactly what `onDisappear`
        // reports.
        //
        // No-ops on the normal finish path — `finish()` has already moved the
        // step to `finished`, so `isRunning` is false by the time this runs.
        .onDisappear {
            guard walkthrough.isRunning else { return }
            walkthrough.interrupt(reason: "routeChanged")
            authManager.markFreeDemoCompleted(handoffToCourses: false)
            // Same reasoning as the finish path: no post-demo ask, so an
            // interrupted script must not leave one armed for a later launch.
            authManager.markPostDemoWallDismissed()
        }
        // The walkthrough's one lasting side effect, and the whole point of it.
        //
        // `finished` is reachable ONLY through `finish()`, i.e. the user tapped
        // through the last beat — an ineligible user stays `dormant`. That is
        // what makes this safe to hang off a step change rather than needing a
        // separate "did they really complete it" signal.
        //
        // Flipping the flag re-renders RootView out of branch 4b and into 4c,
        // the post-demo ask, which is the peak-intent moment the whole script
        // exists to set up. It also releases the one free lesson.
        .onChange(of: walkthrough.step) { newStep in
            guard newStep == .finished else { return }
            log("🎬 MainTabView: walkthrough finished — marking free demo complete")
            authManager.markFreeDemoCompleted()

            // The script now ends straight into the app, with no ask.
            //
            // Dismissing the wall rather than deleting RootView's branch 4c:
            // the branch, the `postDemoWallIsHard` flag and the
            // `source=postDemo` paywall plumbing all still work, so turning the
            // ask back on later is one line here rather than a rebuild. Nothing
            // else sets this flag on this path, so 4c is simply never reached.
            authManager.markPostDemoWallDismissed()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToHomeView"))) { _ in
            log("📱 MainTabView: Received NavigateToHomeView notification - switching to Home tab")
            selectedTab = 0
        }
        // Walkthrough tab driving. A binding rather than a second notification
        // name on purpose: `NavigateToHomeView` is a one-way "go home" signal
        // and does not generalise to "go to tab N".
        //
        // Inert while the script is dormant — `requestedTab` is nil and never
        // changes. Cleared after applying so a later beat asking for the same
        // tab still registers as a change.
        .onChange(of: walkthrough.requestedTab) { requested in
            guard let requested else { return }
            log("🎬 MainTabView: walkthrough requested tab \(requested.rawValue)")
            selectedTab = requested.rawValue
            // Both writes land in the same SwiftUI update, so the tab change
            // and the beat change are rendered together rather than a frame
            // apart. See `tabApplied()`.
            walkthrough.tabApplied()
        }
    }
}

// MARK: - Custom Tab Bar (keeps same name)
struct CustomTabBar: View {
    @Binding var selectedTab: Int

    var body: some View {
        HStack(spacing: 0) {
            TabBarButton(
                icon: "home",
                title: "Home",
                isSelected: selectedTab == 0
            ) { handleTap(0) }

            TabBarButton(
                icon: "map",
                title: "Courses",
                isSelected: selectedTab == 1
            ) { handleTap(1) }

            TabBarButton(
                icon: "calendar",
                title: "Scenarios",
                isSelected: selectedTab == 2
            ) { handleTap(2) }

            TabBarButton(
                icon: "user",
                title: "Profile",
                isSelected: selectedTab == 3
            ) { handleTap(3) }
        }
        .padding(.horizontal, 0)
        .padding(.top, 17) // Reduced from 17 to 12
        .padding(.bottom, -5)
        .frame(maxWidth: .infinity)
        .background(
            CompatibleGlassBackground()
                .clipShape(UnevenRoundedRectangle(
                    topLeadingRadius: 10,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 10,
                    style: .continuous
                ))
                .ignoresSafeArea(edges: .bottom)
            
        )
        .overlay(alignment: .top) {
            // Top border that follows the rounded shape
            UnevenRoundedRectangle(
                topLeadingRadius: 10,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: 10,
                style: .continuous
            )
            .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            .mask(
                // Only show the top part of the stroke
                Rectangle()
                    .frame(height: 15) // Just enough to capture the rounded corners
                    .frame(maxHeight: .infinity, alignment: .top)
            )
        }
    }

    private func handleTap(_ tab: Int) {
        HapticManager.shared.lightImpact()
        if selectedTab == tab {
            NotificationCenter.default.post(name: .scrollToTopTab, object: tab)
        } else {
            selectedTab = tab
        }
    }

    private func bottomPadding() -> CGFloat {
        // Keep the tabbar comfortably above the home indicator
        let bottomSafe = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .safeAreaInsets.bottom ?? 0

        return bottomSafe > 0 ? 0 : 2
    }
}

// MARK: - Tab Bar Button (keeps same name & signature)
struct TabBarButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack() { // Reduced spacing from 6 to 2
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundColor(isSelected ? .wingmanBlack : Color(red: 0.6, green: 0.6, blue: 0.6))

                Text(title)
                    .font(.manropeMedium(size: 10))
                    .foregroundColor(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .fixedSize() // Prevents text from taking extra space
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(ScalePressStyle())
    }
}

// MARK: - UIKit Blur wrapper: keeps a native appearance
struct VisualBlurView: UIViewRepresentable {
    let style: UIBlurEffect.Style

    init(style: UIBlurEffect.Style = .systemUltraThinMaterialLight) {
        self.style = style
    }

    func makeUIView(context: Context) -> UIVisualEffectView {
        let blur = UIBlurEffect(style: style)
        let view = UIVisualEffectView(effect: blur)
        view.clipsToBounds = true
        return view
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        uiView.effect = UIBlurEffect(style: style)
    }
}

// MARK: - Compatible Glass Background
struct CompatibleGlassBackground: UIViewRepresentable {
    func makeUIView(context: Context) -> UIVisualEffectView {
        let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        let visualEffectView = UIVisualEffectView(effect: blurEffect)
        
        // Add a subtle tint for the glass appearance
        let tintView = UIView()
        tintView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        tintView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.contentView.addSubview(tintView)
        
        NSLayoutConstraint.activate([
            tintView.topAnchor.constraint(equalTo: visualEffectView.contentView.topAnchor),
            tintView.leadingAnchor.constraint(equalTo: visualEffectView.contentView.leadingAnchor),
            tintView.trailingAnchor.constraint(equalTo: visualEffectView.contentView.trailingAnchor),
            tintView.bottomAnchor.constraint(equalTo: visualEffectView.contentView.bottomAnchor)
        ])
        
        return visualEffectView
    }
    
    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {
        // Update if needed
    }
}

// MARK: - Previews
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            MainTabView()
                .previewDevice("iPhone 14 Pro")
                .previewDisplayName("iPhone 14 Pro - Light")

            MainTabView()
                .preferredColorScheme(.dark)
                .previewDevice("iPhone 14 Pro")
                .previewDisplayName("iPhone 14 Pro - Dark")
        }
    }
}
