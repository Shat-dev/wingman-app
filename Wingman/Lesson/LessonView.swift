//
//  LessonView.swift
//  Wingman
//

import SwiftUI
import PostHog

struct LessonView: View {
    let lesson: Lesson
    let allLessons: [Lesson]

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var tabBarVisibility: TabBarVisibilityManager
    @EnvironmentObject private var authManager: AuthManager
    @StateObject private var featureFlags = FeatureFlags.shared
    @State private var currentScreenIndex: Int = -1  // -1 means intro screen
    @State private var currentContentIndex: Int = -1 // Index within current screen's content
    @State private var showEndOfLesson = false
    @State private var screenTransitionDirection: Edge = .trailing

    // Analytics: stamped on first appearance so `lesson_completed` can report
    // how long the lesson took. Also guards `lesson_started` against SwiftUI
    // re-firing `.onAppear` on incidental re-mounts.
    @State private var startedAt: Date?

    /// Shared identity properties for the lesson events.
    private var lessonProperties: [String: Any] {
        [
            "lesson_id": lesson.id,
            "lesson_name": lesson.title,
            "category": lesson.courseTitle
        ]
    }

    // Screens sorted by order
    private var sortedScreens: [LessonScreen] {
        lesson.screens.sorted { $0.order < $1.order }
    }
    
    // Current screen
    private var currentScreen: LessonScreen? {
        guard currentScreenIndex >= 0, currentScreenIndex < sortedScreens.count else { return nil }
        return sortedScreens[currentScreenIndex]
    }
    
    // Content for current screen sorted by order
    private var currentScreenContent: [LessonContent] {
        guard let screen = currentScreen else { return [] }
        return screen.content.sorted { $0.order < $1.order }
    }
    
    // Visible content within current screen (accumulated paragraphs)
    private var visibleContent: [LessonContent] {
        guard currentContentIndex >= 0 else { return [] }
        let endIndex = min(currentContentIndex + 1, currentScreenContent.count)
        return Array(currentScreenContent.prefix(endIndex))
    }
    
    // Total content items across all screens (for progress calculation)
    private var totalContentCount: Int {
        sortedScreens.reduce(0) { $0 + $1.content.count }
    }
    
    // Current progress position (for progress bar)
    private var currentProgressPosition: Int {
        guard currentScreenIndex >= 0 else { return 0 }
        
        var position = 0
        for i in 0..<currentScreenIndex {
            position += sortedScreens[i].content.count
        }
        position += (currentContentIndex + 1)
        return position
    }
    
    /// Paragraphs plus knowledge-check questions — one continuous scale across
    /// the whole lesson.
    ///
    /// Reading used to be denominated by paragraphs alone, so the bar hit 100%
    /// on the final paragraph and then appeared to jump *backwards* when the
    /// quiz opened. Counting the questions as steps means reading now fills to
    /// `totalContentCount / totalStepCount` and the quiz carries it the rest of
    /// the way. With no questions the denominator collapses back to the
    /// paragraph count, so a lesson without a check behaves exactly as before.
    private var totalStepCount: Int {
        totalContentCount + quizQuestions.count
    }

    // Progress as a percentage (0.0 to 1.0)
    private var progress: Double {
        guard totalStepCount > 0 else { return 0 }
        return Double(currentProgressPosition) / Double(totalStepCount)
    }
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 12) {
                
                // MARK: - Top Bar (match Auth style: bold chevron + inline progress)
                HStack(spacing: 10) {
                    Button {
                        tabBarVisibility.showTabBar()
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22))
                            .foregroundColor(.wingmanBlack)
                            .frame(width: 44, height: 44, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(ScalePressStyle())
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 10)
                            
                            Capsule()
                                .fill(Color.wingmanBlack)
                                .frame(width: geometry.size.width * CGFloat(progress), height: 10)
                                .animation(.easeInOut(duration: 0.25), value: progress)
                        }
                    }
                    .frame(height: 10)
                }
                .padding(.top, 8)
                .padding(.leading, 5)
                .padding(.trailing, 59)
                .padding(.bottom, 10)
                
                // MARK: - Content Area with Tap Gestures
                GeometryReader { geometry in
                    ZStack {
                        // Content
                        if currentScreenIndex == -1 {
                            // Intro Screen
                            IntroScreenView(
                                onLeftTap: { goBack() },
                                onRightTap: { goForward() }
                            )
                        } else {
                            // Content Screen with Page Transition
                            ContentScreenView(
                                content: visibleContent,
                                screenIndex: currentScreenIndex,
                                screenWidth: geometry.size.width,
                                onLeftTap: { goBack() },
                                onRightTap: { goForward() }
                            )
                            .id("screen_\(currentScreenIndex)")  // Force re-render on screen change
                            .transition(.asymmetric(
                                insertion: .move(edge: screenTransitionDirection).combined(with: .opacity),
                                removal: .move(edge: screenTransitionDirection == .trailing ? .leading : .trailing).combined(with: .opacity)
                            ))
                        }
                    }
                }
                
                // MARK: - Bottom Bar (Lesson Title)
                VStack(spacing: 0) {
                    Text(lesson.title)
                        .font(.manropeSemiBold(size: 12))
                        .foregroundColor(Color(hex: "1A1A1A"))
                        .opacity(0.5)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .padding(.bottom, -10)
            }
        }
        .navigationBarHidden(true)
        .enableInteractivePopGesture()
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            tabBarVisibility.hideTabBar()

            // Analytics: entering the lesson. Guarded so re-mounts don't
            // double-count, and so `startedAt` keeps the original timestamp.
            if startedAt == nil {
                startedAt = Date()
                Analytics.capture(Analytics.Event.lessonStarted, lessonProperties)
            }
        }
        .onDisappear {
            tabBarVisibility.showTabBar()
        }
        .fullScreenCover(isPresented: $showEndOfLesson) {
            LessonQuizFlowView(
                lesson: lesson,
                questions: quizQuestions,
                readingStepCount: totalContentCount,
                nextLessonInfo: getNextLessonInfo(),
                // XP is awarded the moment the completion screen appears, not on
                // the Continue tap. Awarding on Continue meant the screen could
                // only ever show the *previous* completion's award.
                //
                // This does invert the ordering against `markLessonCompleted`
                // below: a force-quit on the completion screen now leaves XP
                // banked for a lesson not marked done. That is self-healing —
                // the ledger is keyed on the lesson id, so finishing it later
                // marks it complete and awards nothing extra — and it is a far
                // smaller problem than a reward screen that cannot show its own
                // reward.
                onReachedCompletion: { correctCount, questionCount in
                    let lessonId = lesson.id
                    Task {
                        await XPStore.shared.award(
                            .lesson,
                            sourceId: lessonId,
                            correctCount: correctCount,
                            questionCount: questionCount
                        )
                    }
                },
                onComplete: {
                    // Analytics fires here rather than when the reading ends.
                    // Previously `lesson_completed` was captured ~2s before
                    // `markLessonCompleted` ran, so a force-quit on the
                    // completion screen left PostHog and stored progress
                    // disagreeing. With a quiz in between that window would be
                    // ~60s and abandonment there is expected, not exceptional —
                    // so the event and the write now happen together, and
                    // `lesson_quiz_abandoned` carries the drop-off signal.
                    var properties = lessonProperties
                    if let startedAt {
                        properties["duration_seconds"] = Analytics.elapsedSeconds(since: startedAt)
                    }
                    // Whether this is the one lesson the walkthrough hands out.
                    // Carried as a property rather than as a separate
                    // `free_lesson_completed` event so the two can never
                    // disagree about what counts as finishing a lesson —
                    // `lesson_completed` already owns that definition, quiz and
                    // all.
                    properties["is_free_lesson"] = (authManager.freeLessonId == lesson.id)
                    Analytics.capture(Analytics.Event.lessonCompleted, properties)

                    LessonDataService.shared.markLessonCompleted(
                        lessonId: lesson.id,
                        courseId: lesson.courseId
                    )

                    tabBarVisibility.showTabBar()
                    dismiss()
                }
            )
            .appDynamicTypeCeiling()
        }
        .trackScreenView("Lesson")
    }
    
    // MARK: - Navigation Functions
    
    private func goBack() {
        screenTransitionDirection = .leading
        
        if currentScreenIndex == -1 {
            // Already at intro, can't go back further
            return
        }
        
        if currentContentIndex > 0 {
            // Remove last paragraph within current screen
            currentContentIndex -= 1
            log("⬅️ Back to content index: \(currentContentIndex) on screen \(currentScreenIndex)")
        } else if currentContentIndex == 0 {
            // At first paragraph of current screen
            if currentScreenIndex > 0 {
                // Go to previous screen, show all its content
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentScreenIndex -= 1
                    let prevScreenContentCount = sortedScreens[currentScreenIndex].content.count
                    currentContentIndex = prevScreenContentCount - 1
                }
                log("⬅️ Previous screen (\(currentScreenIndex)), showing all content")
            } else {
                // At first screen, first content - go to intro
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentScreenIndex = -1
                    currentContentIndex = -1
                }
                log("⬅️ Back to intro")
            }
        } else {
            // currentContentIndex == -1, at start of a screen with no content shown yet
            if currentScreenIndex > 0 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentScreenIndex -= 1
                    let prevScreenContentCount = sortedScreens[currentScreenIndex].content.count
                    currentContentIndex = prevScreenContentCount - 1
                }
                log("⬅️ Previous screen (\(currentScreenIndex))")
            } else {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentScreenIndex = -1
                    currentContentIndex = -1
                }
                log("⬅️ Back to intro")
            }
        }
    }
    
    private func goForward() {
        screenTransitionDirection = .trailing
        
        if currentScreenIndex == -1 {
            // From intro, go to first screen
            withAnimation(.easeInOut(duration: 0.3)) {
                currentScreenIndex = 0
                currentContentIndex = 0
            }
            log("➡️ Started lesson - Screen 0, Content 0")
            return
        }
        
        let screenContentCount = currentScreenContent.count
        
        if currentContentIndex < screenContentCount - 1 {
            // Show next paragraph within current screen
            currentContentIndex += 1
            log("➡️ Forward to content index: \(currentContentIndex) on screen \(currentScreenIndex)")
        } else {
            // All paragraphs shown on current screen, move to next screen
            if currentScreenIndex < sortedScreens.count - 1 {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentScreenIndex += 1
                    currentContentIndex = 0
                }
                log("➡️ Next screen (\(currentScreenIndex)), Content 0")
            } else {
                // Last screen, last content — the reading is done. Whether the
                // lesson is *complete* now depends on the knowledge check; see
                // the cover's `onComplete`.
                log("✅ Lesson reading finished!")
                HapticManager.shared.success()

                // One line that answers "why didn't the knowledge check appear?"
                // without another round trip. Since the question set ships in
                // the bundle, a cold cache is no longer a cause; what is left is
                // the kill switch being on, `-skipLessonQuiz`, a lesson newer
                // than the seed on a device that has not synced, and a missing
                // seed resource (which `LessonQuestionStore` logs on its own).
                let cached = LessonQuestionStore.shared.questionsByLesson
                log("""
                    🧠 End-of-lesson gate — \
                    quizEnabled=\(featureFlags.lessonQuizEnabled) \
                    skipLessonQuiz=\(UserDefaults.standard.bool(forKey: "skipLessonQuiz")) \
                    cachedLessons=\(cached.count) \
                    questionsFor\(lesson.id)=\(cached[lesson.id]?.count ?? 0)
                    """)

                // Surface lessons that have no questions to serve. With a
                // bundled seed this should now be close to zero; if it is not,
                // the seed was cut without that lesson. Without this the
                // fallthrough is silent and invisible in the funnel.
                if featureFlags.lessonQuizEnabled && quizQuestions.isEmpty {
                    var properties = lessonProperties
                    properties["reason"] = "no_questions"
                    Analytics.capture(Analytics.Event.lessonQuizUnavailable, properties)
                }

                showEndOfLesson = true
            }
        }
    }
    
    // MARK: - Knowledge Check
    //
    // Empty means no check: the cover goes straight to `LessonCompleteView` and
    // the lesson finishes exactly as it did before this feature existed. All 94
    // lessons have authored questions and those questions ship in the bundle, so
    // in practice empty now means the `lesson_quiz_disabled` kill switch is on
    // or `-skipLessonQuiz` is set — not a cold cache, which the seed covers.
    private var quizQuestions: [QuizQuestion] {
        // Launch argument: -skipLessonQuiz YES — 94 lessons behind a mandatory
        // check is punishing to QA. Available in Release for the same reason as
        // the kill switch (see FeatureFlags.readLessonQuizEnabled): the flows
        // worth testing are behind a paywall, and paywalls need Release.
        if UserDefaults.standard.bool(forKey: "skipLessonQuiz") { return [] }

        guard featureFlags.lessonQuizEnabled else { return [] }
        return LessonQuestionStore.shared.questions(forLessonId: lesson.id)
    }

    private func getNextLessonInfo() -> NextLessonInfo? {
        if let nextLesson = LessonDataService.shared.getNextLesson(after: lesson) {
            return NextLessonInfo(
                title: nextLesson.title,
                subtitle: nextLesson.courseTitle
            )
        }
        return nil
    }
}

// MARK: - Intro Screen View
struct IntroScreenView: View {
    let onLeftTap: () -> Void
    let onRightTap: () -> Void
    
    // Adjust this to control where the divider sits (0.0 = far left, 1.0 = far right)
    private let dividerPosition: CGFloat = 0.4
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    // Back label area (tappable)
                    VStack {
                        Spacer()
                        Text("Back")
                            .font(.manropeMedium(size: 20))
                            .foregroundColor(Color(hex: "000000"))
                            .opacity(0.5)
                        Spacer()
                    }
                    .frame(width: geo.size.width * dividerPosition)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onLeftTap()
                    }

                    // Forward label area (tappable)
                    VStack {
                        Spacer()
                        Text("Forward")
                            .font(.manropeMedium(size: 20))
                            .foregroundColor(Color(hex: "000000"))
                            .opacity(0.5)
                        Spacer()
                    }
                    .frame(width: geo.size.width * (1 - dividerPosition))
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onRightTap()
                    }
                }

                // Divider with top and bottom padding
                let topPadding: CGFloat = 20
                let bottomPadding: CGFloat = 40
                let paddedHeight = max(0, geo.size.height - (topPadding + bottomPadding))
                let centerYOffset = (topPadding - bottomPadding) / 2 // shift center when paddings differ
                
                Rectangle()
                    .fill(Color.wingmanBlack.opacity(0.5))
                    .frame(width: 1, height: paddedHeight)
                    .position(
                        x: geo.size.width * dividerPosition,
                        y: geo.size.height / 2 + centerYOffset
                    )
                    .allowsHitTesting(false)
            }
        }
        .padding(.horizontal, 0)
    }
}

// MARK: - Content Screen View (with scroll support and tap gestures)
struct ContentScreenView: View {
    let content: [LessonContent]
    let screenIndex: Int
    let screenWidth: CGFloat
    let onLeftTap: () -> Void
    let onRightTap: () -> Void
    
    var body: some View {
        ScrollableContentView(
            content: content,
            screenWidth: screenWidth,
            onLeftTap: onLeftTap,
            onRightTap: onRightTap
        )
    }
}

// MARK: - UIKit ScrollView wrapper that handles both scroll and taps
struct ScrollableContentView: UIViewRepresentable {
    let content: [LessonContent]
    let screenWidth: CGFloat
    let onLeftTap: () -> Void
    let onRightTap: () -> Void
    
    func makeCoordinator() -> Coordinator {
        Coordinator(screenWidth: screenWidth, onLeftTap: onLeftTap, onRightTap: onRightTap)
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        
        // Add tap gesture that doesn't interfere with scroll
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delaysTouchesBegan = false
        tapGesture.delaysTouchesEnded = false
        scrollView.addGestureRecognizer(tapGesture)
        
        // Create content view
        let contentView = UIView()
        contentView.backgroundColor = .clear
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Store reference
        context.coordinator.contentView = contentView
        context.coordinator.scrollView = scrollView
        
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])
        
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.screenWidth = screenWidth
        context.coordinator.onLeftTap = onLeftTap
        context.coordinator.onRightTap = onRightTap
        
        guard let contentView = context.coordinator.contentView else { return }
        
        // Remove old labels
        contentView.subviews.forEach { $0.removeFromSuperview() }
        
        // Create stack of labels
        var lastLabel: UILabel?
        let topPadding: CGFloat = 0
        let bottomPadding: CGFloat = 120
        let horizontalPadding: CGFloat = 20
        let paragraphSpacing: CGFloat = 10
        
        for item in content {
            let label = UILabel()
            label.text = item.text
            label.numberOfLines = 0
            label.textColor = .wingmanBlack
            label.translatesAutoresizingMaskIntoConstraints = false
            
            // Set Manrope font
            if let manropeFont = UIFont(name: "Manrope-Medium", size: 24) {
                label.font = manropeFont
            } else {
                label.font = UIFont.systemFont(ofSize: 24, weight: .medium)
            }
            
            // Set line spacing
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = 8
            let attributedString = NSAttributedString(
                string: item.text,
                attributes: [
                    .font: label.font!,
                    .foregroundColor: UIColor.wingmanBlack,
                    .paragraphStyle: paragraphStyle
                ]
            )
            label.attributedText = attributedString
            
            contentView.addSubview(label)
            
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: horizontalPadding),
                label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -horizontalPadding)
            ])
            
            if let last = lastLabel {
                label.topAnchor.constraint(equalTo: last.bottomAnchor, constant: paragraphSpacing).isActive = true
            } else {
                label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: topPadding).isActive = true
            }
            
            lastLabel = label
        }
        
        // Set bottom constraint
        if let last = lastLabel {
            last.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -bottomPadding).isActive = true
        }
        
        // Only auto-scroll when content exceeds bounds and there are multiple paragraphs
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let needsScroll = scrollView.contentSize.height > scrollView.bounds.height + 1
            let hasMultiple = content.count > 1
            if needsScroll && hasMultiple {
                let bottomOffset = CGPoint(
                    x: 0,
                    y: max(0, scrollView.contentSize.height - scrollView.bounds.height + scrollView.contentInset.bottom)
                )
                scrollView.setContentOffset(bottomOffset, animated: true)
            } else {
                // Keep first paragraph pinned to top
                scrollView.setContentOffset(.zero, animated: false)
            }
        }
    }
    
    class Coordinator: NSObject {
        var screenWidth: CGFloat
        var onLeftTap: () -> Void
        var onRightTap: () -> Void
        weak var contentView: UIView?
        weak var scrollView: UIScrollView?
        
        init(screenWidth: CGFloat, onLeftTap: @escaping () -> Void, onRightTap: @escaping () -> Void) {
            self.screenWidth = screenWidth
            self.onLeftTap = onLeftTap
            self.onRightTap = onRightTap
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            let location = gesture.location(in: gesture.view)
            let midPoint = screenWidth / 2
            
            if location.x < midPoint {
                log("🔵 LEFT TAP at x: \(location.x)")
                onLeftTap()
            } else {
                log("🟢 RIGHT TAP at x: \(location.x)")
                onRightTap()
            }
        }
    }
}

// MARK: - Color Extension
#Preview {
    LessonView(
        lesson: Lesson(
            id: "lesson_1_1",
            courseId: "course_1",
            courseSummary: "Learn to strengthen confidence by reframing limiting beliefs.",
            courseTitle: "Beliefs & Reframes",
            lessonNumber: 1,
            title: "You are not your thoughts",
            duration: 3,
            summary: "Learn why negative thoughts feel convincing and how to stop letting them control you.",
            isCompleted: false,
            isLocked: false,
            screens: [
                LessonScreen(id: "screen_1", order: 0, content: [
                    LessonContent(id: "c1", text: "Your mind produces around 60,000 thoughts a day. Most are repetitive, some are negative, and nearly all vanish without impact. Yet we treat them like evidence of who we are.", order: 0),
                    LessonContent(id: "c2", text: "These thoughts aren't conscious choices; they are automatic reactions shaped by habit, fear, and memory. The problem isn't having them; it's believing each one reflects reality.", order: 1)
                ]),
                LessonScreen(id: "screen_2", order: 1, content: [
                    LessonContent(id: "c3", text: "A single thought—\"I sounded awkward\"—can shift your entire state. It tightens your body, changes how you speak, and changes how you see yourself.", order: 0),
                    LessonContent(id: "c4", text: "You begin responding not to the world as it is, but to the critical story you have started telling yourself.", order: 1)
                ])
            ]
        ),
        allLessons: []
    )
    .environmentObject(TabBarVisibilityManager())
    .environmentObject(AuthManager())
}
