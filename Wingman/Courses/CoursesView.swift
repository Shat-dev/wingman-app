//
//  CoursesView.swift
//  Wingman
//

import SwiftUI
import PostHog

struct CoursesView: View {
    // Observe router to receive deep-link open requests
    @EnvironmentObject private var coursesRouter: CoursesRouter
    
    @StateObject private var viewModel = CoursesViewModel()
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var categoryScrollProxy: ScrollViewProxy? = nil
    @State private var isUserScrolling = false  // Track if user manually clicked a pill
    @State private var didApplyInitialScroll = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                if viewModel.isLoading {
                    // Loading state
                    VStack {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .wingmanBlack))
                            .scaleEffect(1.2)
                        Spacer()
                    }
                } else {
                    VStack(spacing: 0) {

                        // MARK: - Header
                        Text("Courses")
                            .font(.manropeMedium(size: 24))
                            .foregroundColor(.wingmanBlack)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 16)
                        
                        // MARK: - Category Pills
                        ScrollViewReader { categoryProxy in
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(viewModel.availableCategories) { category in
                                        CategoryPill(
                                            title: category.name,
                                            isSelected: viewModel.selectedCategoryId == category.id
                                        ) {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                HapticManager.shared.selection()
                                                // Set flag to indicate user manually clicked
                                                isUserScrolling = true
                                                viewModel.selectCategory(category.id)
                                                // Scroll to the selected category
                                                scrollProxy?.scrollTo(category.id, anchor: .top)
                                                
                                                // Reset flag after animation completes
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                    isUserScrolling = false
                                                }
                                            }
                                        }
                                        .id("pill_\(category.id)")
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                            .onAppear {
                                categoryScrollProxy = categoryProxy
                            }
                        }
                        .padding(.bottom, 20)
                        
                        // MARK: - All Courses (Scrollable)
                        ScrollViewReader { proxy in
                            ScrollView(showsIndicators: false) {
                                LazyVStack(alignment: .leading, spacing: 20, pinnedViews: [.sectionHeaders]) {
                                    Color.clear.frame(height: 0).id("top")
                                    ForEach(viewModel.availableCategories) { category in
                                        Section(header: CategoryHeader(title: category.name)) {
                                            CoursesGrid(courses: category.courses, viewModel: viewModel)
                                        }
                                        .id(category.id)
                                        .onAppear {
                                            // Only auto-select if user is NOT manually scrolling
                                            if !isUserScrolling {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    viewModel.selectCategory(category.id)
                                                    // Auto-scroll the category pills to keep selected one visible
                                                    categoryScrollProxy?.scrollTo("pill_\(category.id)", anchor: .center)
                                                }
                                            }
                                        }
                                    }

                                }

                                Spacer().frame(height: 100)
                            }
                            .padding(.horizontal, 20)
                            .onAppear {
                                scrollProxy = proxy

                                // Apply initial deep-linking after data is ready (once)
                                if !didApplyInitialScroll {
                                    didApplyInitialScroll = true
                                    applyDeepLinkIfNeeded()
                                }
                            }
                            .onReceive(NotificationCenter.default.publisher(for: .scrollToTopTab)) { note in
                                guard (note.object as? Int) == 1 else { return }
                                withAnimation(.easeOut(duration: 0.3)) {
                                    proxy.scrollTo("top", anchor: .top)
                                    if let firstId = viewModel.availableCategories.first?.id {
                                        categoryScrollProxy?.scrollTo("pill_\(firstId)", anchor: .leading)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear {
                // Try again when view appears (in case data finished after)
                applyDeepLinkIfNeeded()
            }
            // React to new open requests while Courses tab is visible
            .onReceive(coursesRouter.$trigger) { _ in
                // Ensure we are on Courses tab when an open request arrives; MainTabView handles tab switch.
                applyDeepLinkIfNeeded()
            }
        }
        .postHogScreenView("Courses")
    }
    
    private func applyDeepLinkIfNeeded() {
        guard !viewModel.isLoading,
              let categoryId = coursesRouter.initialSelectedCategoryId
        else { return }
        
        // We are programmatically controlling selection/scrolling
        isUserScrolling = false
        
        // Select the category
        withAnimation(.easeInOut(duration: 0.25)) {
            viewModel.selectCategory(categoryId)
        }
        
        // Scroll vertical list to category section
        if let scrollProxy {
            withAnimation(.easeInOut(duration: 0.35)) {
                scrollProxy.scrollTo(categoryId, anchor: .top)
            }
        } else {
            // Retry shortly if proxy not ready yet
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                applyDeepLinkIfNeeded()
            }
        }
        
        // Center the horizontal pill for that category
        if let categoryScrollProxy {
            withAnimation(.easeInOut(duration: 0.35)) {
                categoryScrollProxy.scrollTo("pill_\(categoryId)", anchor: .center)
            }
        }
    }
}

// MARK: - Category Pill
struct CategoryPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.manropeMedium(size: 14))
                .foregroundColor(isSelected ? .wingmanBlack : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected ? Color.white : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .strokeBorder(isSelected ? Color.wingmanBlack : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Header
struct CategoryHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.manropeMedium(size: 16))
            .foregroundColor(.wingmanBlack)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .background(Color.white)
    }
}

// MARK: - Courses Grid
struct CoursesGrid: View {
    let courses: [Course]
    /// Must be @ObservedObject (not a plain `let`) so this view re-renders
    /// when `progressVersion` is bumped after a lesson completion — otherwise
    /// captured `lockReason` values stay stale and newly unlocked courses
    /// still appear locked until the app is restarted.
    @ObservedObject var viewModel: CoursesViewModel

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(courses) { course in
                let lockReason = viewModel.courseLockReason(course)
                NavigationLink(destination: CourseDetailSheet(course: course, lockReason: lockReason)) {
                    CourseCardContent(course: course, lockReason: lockReason)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Course Card Content
struct CourseCardContent: View {
    let course: Course
    var lockReason: CourseLockReason = .unlocked

    private var isLocked: Bool { lockReason.isLocked }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Thumbnail with illustration - Fixed height
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Rectangle()
                        .fill(Color(.white))
                        .frame(height: 160)

                    Image(getImageForCourse())
                        .resizable()
                        .scaledToFit()
                        .padding(0)
                }
                .opacity(isLocked ? 0.3 : 1.0)

                if isLocked {
                    // Match the scenario-card lock styling exactly: natural
                    // asset size (20×22 SVG) + opacity(0.7). Resizing to 18×18
                    // made the 2px strokes anti-alias to gray, which read as a
                    // faded icon even though the opacity was effectively 1.0.
                    Image("lock_icon")
                        .foregroundColor(.wingmanBlack)
                        .opacity(0.7)
                        .padding(10)
                }
            }

            Divider()
                .background(Color.gray.opacity(0.2))

            // Title section with fixed 2-line height
            Text(course.title)
                .font(.manropeMedium(size: 14))
                .foregroundColor(isLocked ? Color.wingmanBlack.opacity(0.3) : .wingmanBlack)
                .lineSpacing(1)
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .frame(minHeight: 44)
                .padding(.horizontal, 8)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .background(Color.white)
        }
        .frame(minHeight: 245)
        .background(Color.white)
        .cornerRadius(5)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.wingmanBlack.opacity(0.08), lineWidth: 1)
        )
    }
    
    private func getImageForCourse() -> String {
        // Map Course thumbnailName to actual image assets
        switch course.thumbnailName {
        // Mindset & Foundations
        case "course_beliefs": return "beliefandreframes"
        case "course_fear": return "fearandexposure"
        case "course_presence": return "presenceandexpresions"
        case "course_stability": return "innerstability"
        case "course_nonnegotiables": return "nonnegotiables"
        
        // Approach Mechanics
        case "course_readiness": return "approachreadiness"
        case "course_physical": return "thephysicalapproch"
        case "course_opener": return "theopner"
        case "course_reading": return "readingandresponding"
        case "course_situational": return "situationspecficapproaches"
        case "course_advanced": return "advanceopeningtechniques"
        
        // Conversation Flow
        case "course_smalltalk": return "smalltalkandmomentum"
        case "course_listening": return "ListeningandAttunement"
        case "course_vulnerability": return "Sharing&Vulnerability"
        case "course_closing": return "closing"
        case "course_advconvo": return "Advancedconversationskills"
        
        // Flirting & Chemistry
        case "course_flirtprereq": return "FlirtingPrerequisites"
        case "course_playfulness": return "Playfulness&Spark"
        case "course_compliments": return "Compliments&VerbalChemistry"
        case "course_physical_presence": return "PhysicalPresence&Escalation"
        case "course_advflirt": return "AdvancedFlirtingSkills"
        
        // Integration & Mastery
        case "course_lifestyle": return "Upgradingyourlifestyle"
        case "course_opportunities": return "CreatingOpportunties"
        case "course_mastery": return "Mastery&Identity"
        case "course_selfdiscovery": return "Learning&SelfDiscovery"
        
        default: return "book"
        }
    }
}

#Preview {
    CoursesView()
        .environmentObject(CoursesRouter())
}
