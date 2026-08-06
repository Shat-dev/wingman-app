//
//  HomeView.swift
//  Wingman
//

import SwiftUI
import Auth
import Supabase
import PostHog

struct HomeView: View {
    // Binding added so Home can change the selected tab in MainTabView
    @Binding var selectedTab: Int
    @EnvironmentObject private var coursesRouter: CoursesRouter
    @EnvironmentObject private var tabBarVisibility: TabBarVisibilityManager
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var walkthrough: WalkthroughCoordinator

    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var navigateToPractice = false
    @State private var showLogApproachSheet = false
    @State private var selectedCourse: Course? = nil
    @State private var currentModulePage: Int = 0
    // Feature-gate paywall for Daily Practice Start (free users).
    @State private var showDailyPracticePaywall = false
    
    // Module data for carousel
    private var modules: [(category: CourseCategory, title: String, subtitle: String, imageName: String)] {
        let categories = CourseCategory.dummyCategories
        return [
            (categories[0], "Mindset & Foundations", "", "beliefandreframes"),
            (categories[1], "Approach Mechanics", "", "approch_mech_ym"),
            (categories[2], "Conversation Flow", "", "smalltalkandmomentum"),
            (categories[3], "Flirting & Chemistry", "", "Flirting_ym"),
            (categories[4], "Integration & Mastery", "", "Mastery&Identity")
        ]
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {

                    // MARK: - Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Good Morning," )
                                .font(.manropeMedium(size: 24))
                                .foregroundColor(.wingmanBlack)
                            
                            // Show user name from Supabase userMetadata["display_name"].
                            // Falls back to "User" if unset — we never surface the
                            // email here, since a long email prefix would overflow
                            // this 24pt greeting and bypass the 10-char name cap.
                            // Read via the already-observed @Published currentUser
                            // so edits to display_name reactively re-render this
                            // header, and so body doesn't do a singleton dereference
                            // on every render.
                            if let user = authManager.currentUser,
                               let name = user.userMetadata["display_name"]?.stringValue,
                               !name.isEmpty {
                                Text(name)
                                    .font(.manropeMedium(size: 24))
                                    .foregroundColor(Color(hex: "1A1A1A").opacity(0.7))
                            } else {
                                Text("User")
                                    .font(.manropeMedium(size: 24))
                                    .foregroundColor(Color(hex: "1A1A1A").opacity(0.7))
                            }
                        }
                        
                        Spacer()
                        
                        // MARK: - Streak Badge
                        HStack(spacing: 2) {
                            Image("flame_fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .padding(.leading, 16)

                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .wingmanBlack))
                                    .scaleEffect(0.7)
                                    .frame(width: 20, height: 20)
                                    .padding(.trailing, 16)
                            } else {
                                Text("\(viewModel.currentStreak)")
                                    .font(.manropeMedium(size: 20))
                                    .padding(.trailing, 16)
                            }
                        }
                        .foregroundColor(.wingmanBlack)
                        .frame(minWidth: 64, minHeight: 44, maxHeight: 44)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.wingmanBlack.opacity(0.15), lineWidth: 1)
                        )
                        .cornerRadius(5)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                    
                    ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            Color.clear.frame(height: 0).id("top")

                            // MARK: - Daily Practice Card
                            VStack(spacing: 0) {
                                VStack(spacing: 0) {
                                    Text("Daily Practice")
                                        .font(.manropeMedium(size: 20))
                                        .foregroundColor(.wingmanBlack)
                                        .padding(.top, 20)
                                        .frame(maxWidth: .infinity)

                                    Text("Suggested")
                                        .font(.manropeMedium(size: 14))
                                        .foregroundColor(.gray)
                                        .padding(.top, 8)
                                        .frame(maxWidth: .infinity)

                                    // Offline adds a disabled "No Connection" state on top of the
                                    // existing isDailyPracticeButtonEnabled gate (which handles
                                    // "already completed today"). Both must be true to start.
                                    let canStart = networkMonitor.isConnected && viewModel.isDailyPracticeButtonEnabled
                                    let buttonText = networkMonitor.isConnected ? viewModel.dailyPracticeButtonText : "No Connection"

                                    Button(action: {
                                        if canStart {
                                            HapticManager.shared.mediumImpact()
                                            // Walkthrough interception, ahead
                                            // of the paywall — daily practice
                                            // is not part of the script and
                                            // must not derail it.
                                            if walkthrough.isIntercepting {
                                                walkthrough.showNudge(.dailyPractice)
                                            } else if authManager.hasActiveSubscription {
                                                navigateToPractice = true
                                            } else {
                                                showDailyPracticePaywall = true
                                            }
                                        }
                                    }) {
                                        Text(buttonText)
                                            .font(.manropeSemiBold(size: 16))
                                            .foregroundColor(.wingmanWhiteFF)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 52)
                                            .background(canStart ? Color.wingmanBlack : Color.wingmanBlack.opacity(0.5))
                                            .cornerRadius(5)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(ScalePressStyle())
                                    .disabled(!canStart)
                                    .padding(.horizontal, 20)
                                    .padding(.bottom, 20)
                                    .padding(.top, 40)
                                }
                            }
                            .frame(height: 200)
                            .frame(maxWidth: .infinity)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                            .overlay(
                                Image("dp_wm_logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 109) // Adjust height automatically to maintain aspect ratio
                                    .opacity(0.10)
                                    // No heavy negative padding needed
                                    .padding(.top, 3)    // Small nudge from the top edge
                                    .padding(.leading, 3), // Small nudge from the right edge
                                alignment: .topLeading // This anchors it to the corner
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                            .padding(.horizontal, 20)
                            
                            // MARK: - Log Today's Approach
                            Button(action: {
                                showLogApproachSheet = true
                            }) {
                                HStack(spacing: 10) {
                                    Image("feather")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 22, height: 22)
                                        .foregroundColor(.wingmanBlack)

                                    Text("Log Approach")
                                        .font(.manropeSemiBold(size: 16))
                                        .foregroundColor(.wingmanBlack)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.wingmanBlack.opacity(0.35), lineWidth: 1)
                                )
                                .cornerRadius(5)
                            }
                            .buttonStyle(ScalePressStyle())
                            .padding(.horizontal, 20)

                            Divider().background(Color.gray.opacity(0.2))
                            
                            
                            // MARK: - Motivational Quote
                            VStack(alignment: .leading) {
                                Image("quote_sign")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 30, height: 30)


                                Text(viewModel.motivationalQuote)
                                    .font(.georgiaItalic(size: 16))
                                    .foregroundColor(Color.wingmanBlack.opacity(0.75))
                                    .multilineTextAlignment(.leading)
                                    .lineSpacing(3)
                                    .padding(.top, 0)

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 40)
                            
                            Divider().background(Color.gray.opacity(0.2))
                            
                            // MARK: - Continue Section (Single Course - Only show if course exists)
                            if let course = viewModel.continueCourse {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Continue")
                                        .font(.manropeMedium(size: 20))
                                        .foregroundColor(.wingmanBlack)
                                        .padding(.horizontal, 20)
                                    
                                    // Continue Course Card - Pixel Perfect Design
                                    ContinueCourseCard(course: course) {
                                        // Restore previous behavior: push directly to the last course
                                        if let found = findCourse(courseId: course.courseId) {
                                            selectedCourse = found
                                        }
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            
                            // MARK: - Your Modules Section (Custom Swipeable Carousel with Peek)
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Your Modules")
                                    .font(.manropeMedium(size: 20))
                                    .foregroundColor(.wingmanBlack)
                                    .padding(.horizontal, 20)
                                
                                // Custom Swipeable Carousel with peek
                                PeekCarousel(
                                    modules: modules,
                                    currentPage: $currentModulePage,
                                    onModuleSelected: { category in
                                        // Switch tab to Courses and deep link to category
                                        selectedTab = 1
                                        coursesRouter.open(categoryId: category.id, courseId: category.courses.first?.id)
                                    }
                                )
                            }
                            
                            Spacer().frame(height: 100)
                        }
                        .padding(.top, 8)
                    }
                    .onReceive(NotificationCenter.default.publisher(for: .scrollToTopTab)) { note in
                        guard (note.object as? Int) == 0 else { return }
                        withAnimation(.easeOut(duration: 0.3)) {
                            proxy.scrollTo("top", anchor: .top)
                        }
                    }
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: Binding(
                get: { selectedCourse != nil },
                set: { if !$0 { selectedCourse = nil } }
            )) {
                if let course = selectedCourse {
                    CourseDetailSheet(course: course)
                }
            }
            .navigationDestination(isPresented: $navigateToPractice) {
                DailyPracticeView(onCompletionDismiss: { navigateToPractice = false })
                    .environmentObject(tabBarVisibility)
            }
            .sheet(isPresented: $showLogApproachSheet) {
                LogApproachBottomSheet(isPresented: $showLogApproachSheet, approachToEdit: nil)
                    // SE-only: offer a resizable fractional detent alongside
                    // `.large` so users can drag the sheet shorter if the
                    // TextEditor/Slider stack feels cramped. Standard / Max
                    // phones retain the original `.large`-only behavior.
                    .presentationDetents(UIScreen.isSmallPhone ? [.fraction(0.9), .large] : [.large])
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(20)
            }
            .subscriptionGate(isPresented: $showDailyPracticePaywall)
            .onAppear {
                log("👁️ HomeView appeared - refreshing continue course and daily practice status")
                viewModel.loadUserData()
                viewModel.loadContinueCourse()
                // refreshDailyPracticeStatus() intentionally omitted: loadUserData()
                // already spawns checkDailyPracticeCompletion(), so calling both
                // fires the same RPC twice.
            }
        }
        .trackScreenView("Home")
    }
    
    // MARK: - Find Course by ID
    private func findCourse(courseId: String) -> Course? {
        for category in CourseCategory.dummyCategories {
            if let course = category.courses.first(where: { $0.id == courseId }) {
                return course
            }
        }
        return nil
    }
}

// MARK: - Peek Carousel (Custom swipeable with peek effect)
struct PeekCarousel: View {
    let modules: [(category: CourseCategory, title: String, subtitle: String, imageName: String)]
    @Binding var currentPage: Int
    let onModuleSelected: (CourseCategory) -> Void
    
    @State private var dragOffset: CGFloat = 0
    @State private var screenWidth: CGFloat = UIScreen.main.bounds.width
    @GestureState private var isHorizontalDrag: Bool = false
    @State private var horizontalDragActive: Bool = false

    // Layout constants
    private let cardSpacing: CGFloat = 12
    private let horizontalPadding: CGFloat = 20
    private let peekAmount: CGFloat = 40  // How much of next card to show

    private var cardWidth: CGFloat {
        screenWidth - horizontalPadding - peekAmount - cardSpacing
    }

    // Toggle to enable/disable custom horizontal pan detection overlay for the carousel
    private let useCarouselPan = true

    // Carousel row height, scaled with Dynamic Type so the cards' text gets
    // more room as text grows instead of being clipped by the fixed row.
    // Equals 430 at the default text size — no change until the app-wide
    // ceiling is raised above `.large`.
    @ScaledMetric(relativeTo: .body) private var moduleCarouselHeight: CGFloat = 430

    var body: some View {
        VStack(spacing: 16) {
            // Cards in GeometryReader
            GeometryReader { geometry in
                let width = geometry.size.width
                let calculatedCardWidth = width - horizontalPadding - peekAmount - cardSpacing

                HStack(spacing: cardSpacing) {
                    ForEach(Array(modules.enumerated()), id: \.offset) { index, module in
                        ModuleCarouselCard(
                            title: module.title,
                            subtitle: module.subtitle,
                            imageName: module.imageName
                        ) {
                            onModuleSelected(module.category)
                        }
                        .frame(width: calculatedCardWidth)
                    }
                }
                .offset(x: calculateOffset(screenWidth: width, cardWidth: calculatedCardWidth))
                .simultaneousGesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            // Only handle horizontal drags
                            if abs(value.translation.width) > abs(value.translation.height) {
                                let maxOffset = calculatedCardWidth + 60
                                let x = max(min(value.translation.width, maxOffset), -maxOffset)
                                dragOffset = x
                                horizontalDragActive = true
                            }
                        }
                        .onEnded { value in
                            if horizontalDragActive {
                                let predicted = value.translation.width + value.predictedEndTranslation.width * 0.3
                                let threshold = calculatedCardWidth / 3
                                let previousPage = currentPage
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    if predicted < -threshold && currentPage < modules.count - 1 {
                                        currentPage += 1
                                    } else if predicted > threshold && currentPage > 0 {
                                        currentPage -= 1
                                    }
                                    dragOffset = 0
                                    horizontalDragActive = false
                                }
                                if currentPage != previousPage {
                                    HapticManager.shared.selection()
                                }
                            }
                        }
                )
                .onAppear {
                    screenWidth = width
                }
            }
            .frame(height: moduleCarouselHeight) // Cards only

            // Page Indicators - OUTSIDE GeometryReader
            HStack(spacing: 8) {
                ForEach(0..<modules.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.wingmanBlack : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: currentPage)
        }
    }

    private func calculateOffset(screenWidth: CGFloat, cardWidth: CGFloat) -> CGFloat {
        let totalCardWidth = cardWidth + cardSpacing
        let baseOffset = horizontalPadding - (CGFloat(currentPage) * totalCardWidth)
        return baseOffset + dragOffset
    }
}

// MARK: - Module Carousel Card (Pixel Perfect)
struct ModuleCarouselCard: View {
    let title: String
    let subtitle: String
    let imageName: String
    let onOpen: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Illustration Area
            ZStack {
                Rectangle()
                    .fill(Color.white)
                
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .padding(0)
            }
            .frame(height: 280)
            
            // Divider
            Rectangle()
                .fill(Color.gray.opacity(0.15))
                .frame(height: 1)
            
            // Content Area
            VStack(spacing: 10) {
                // Title
                Text(title)
                    .font(.manropeMedium(size: 18))
                    .foregroundColor(.wingmanBlack)
                    .multilineTextAlignment(.center)
                
                // Subtitle
                Text(subtitle)
                    .font(.manropeMedium(size: 14))
                    .foregroundColor(Color.gray)
                
                // Open Button
                Button(action: onOpen) {
                    Text("Open")
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.wingmanBlack)
                        .cornerRadius(5)
                }
                .buttonStyle(ScalePressStyle())
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color.white)
        .cornerRadius(5)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.wingmanBlack.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.wingmanBlack.opacity(0.06), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Continue Course Card (Pixel Perfect - Matches Screenshot)
struct ContinueCourseCard: View {
    let course: ContinueCourse
    let onTap: () -> Void

    // Card height, scaled with Dynamic Type so the title/progress get more
    // room as text grows. Equals 132 at the default text size — no change
    // until the app-wide ceiling is raised above `.large`.
    @ScaledMetric(relativeTo: .body) private var continueCardHeight: CGFloat = 132
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // MARK: - Left: Square Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.white)
                    
                    Image(course.thumbnailName)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                }
                .frame(width: 94, height: 94)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                )
                
                // MARK: - Right: Content
                VStack(alignment: .leading, spacing: 0) {
                    // Title: "Category: Course Name"
                    Text("\(course.categoryName): \(course.courseName)")
                        .font(.manropeMedium(size: 16))
                        .foregroundColor(.wingmanBlack)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                    
                    // Progress Bar with Percentage
                    HStack(spacing: 12) {
                        // Progress Bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(hex: "E5E5E5"))
                                    .frame(height: 4)
                                    
                                
                                // Filled progress
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.wingmanBlack)
                                    .frame(width: geometry.size.width * course.progress, height: 4)
                            }
                        }
                        .frame(height: 4)

                        // Percentage
                        Text("\(Int(course.progress * 100))%")
                            .font(.manropeMedium(size: 14))
                            .foregroundColor(Color(hex: "000000"))
                            .frame(width: 40)

                    }
                }
                .padding(.vertical,10)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: continueCardHeight)
            .background(Color.white)
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.wingmanBlack.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(ScalePressStyle())
    }
}

// MARK: - Make Course Hashable for navigationDestination
extension Course: Hashable {
    static func == (lhs: Course, rhs: Course) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

#Preview {
    // Provide a constant binding for previews
    HomeView(selectedTab: .constant(0))
        .environmentObject(TabBarVisibilityManager())
        .environmentObject(CoursesRouter())
        .environmentObject(AuthManager())
        .environmentObject(WalkthroughCoordinator())
}

struct HorizontalPanGestureView: UIViewRepresentable {
    let onChanged: (CGPoint) -> Void
    let onEnded: (CGPoint, CGPoint) -> Void

    init(onChanged: @escaping (CGPoint) -> Void, onEnded: @escaping (CGPoint, CGPoint) -> Void) {
        self.onChanged = onChanged
        self.onEnded = onEnded
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onChanged: onChanged, onEnded: onEnded)
    }

    func makeUIView(context: Context) -> PassThroughView {
        let view = PassThroughView(frame: .zero)
        view.backgroundColor = .clear
        view.isUserInteractionEnabled = true
        view.coordinator = context.coordinator // Set coordinator reference
        
        let panGesture = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        panGesture.delegate = context.coordinator
        // Do not cancel or delay touches so vertical scrolling and taps aren't blocked
        panGesture.cancelsTouchesInView = false
        panGesture.delaysTouchesBegan = false
        panGesture.delaysTouchesEnded = false
        panGesture.minimumNumberOfTouches = 1
        panGesture.maximumNumberOfTouches = 1
        view.addGestureRecognizer(panGesture)
        view.setupPanGesture(panGesture) // Pass reference to view
        return view
    }

    func updateUIView(_ uiView: PassThroughView, context: Context) {
        uiView.coordinator = context.coordinator // Update coordinator reference
    }

    class Coordinator: NSObject, UIGestureRecognizerDelegate {
        let onChanged: (CGPoint) -> Void
        let onEnded: (CGPoint, CGPoint) -> Void
        var isHorizontalPan: Bool = false // Made accessible for PassThroughView

        init(onChanged: @escaping (CGPoint) -> Void, onEnded: @escaping (CGPoint, CGPoint) -> Void) {
            self.onChanged = onChanged
            self.onEnded = onEnded
        }

        @objc func handlePan(_ pan: UIPanGestureRecognizer) {
            let translation = pan.translation(in: pan.view)
            let velocity = pan.velocity(in: pan.view)

            switch pan.state {
            case .began:
                // Determine if this is a horizontal pan at the start
                isHorizontalPan = abs(velocity.x) > abs(velocity.y) * 1.2
            case .changed:
                // Only forward predominantly horizontal movements
                if isHorizontalPan && abs(translation.x) > abs(translation.y) {
                    onChanged(translation)
                }
            case .ended, .cancelled, .failed:
                if isHorizontalPan {
                    onEnded(translation, velocity)
                }
                isHorizontalPan = false
            default:
                break
            }
        }

        // Allow simultaneous recognition so vertical scroll and taps remain responsive
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return true
        }

        // Only begin the pan if the initial velocity/translation indicates a horizontal gesture
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer, let view = pan.view else { return false }
            let velocity = pan.velocity(in: view)
            // If we have clear horizontal velocity, begin
            if abs(velocity.x) > abs(velocity.y) * 1.3 && abs(velocity.x) > 20 {
                return true
            }
            // Otherwise use translation as fallback
            let translation = pan.translation(in: view)
            if abs(translation.x) > abs(translation.y) * 1.6 && abs(translation.x) > 12 {
                return true
            }
            return false
        }
        
        // Don't require the gesture to fail before allowing other gestures
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return false
        }
        
        // Don't be required to fail by other gestures
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            return false
        }
    }
}

// MARK: - Pass Through View (allows taps to pass through while handling horizontal pans)
class PassThroughView: UIView {
    weak var coordinator: HorizontalPanGestureView.Coordinator?
    private var panGesture: UIPanGestureRecognizer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.isUserInteractionEnabled = true
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    func setupPanGesture(_ gesture: UIPanGestureRecognizer) {
        self.panGesture = gesture
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // Only allow pan gestures that are horizontal to begin on this view
        if let pan = gestureRecognizer as? UIPanGestureRecognizer {
            let velocity = pan.velocity(in: self)
            return abs(velocity.x) > abs(velocity.y) * 1.2
        }
        return false
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Check if we have an active horizontal pan gesture
        if let pan = panGesture, pan.state == .began || pan.state == .changed {
            return self
        }
        
        // For initial touches, return self so our gesture recognizer can evaluate if it should begin
        // But because cancelsTouchesInView = false, taps will still reach underlying views
        return self
    }
    
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return true
    }
}
