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

    /// Coordinate space for the vertical course list, so each section can report
    /// where it actually sits relative to the top of the visible area.
    private let scrollSpace = "coursesScroll"

    /// Vertical spacing the course list's `LazyVStack` puts between a pinned
    /// section header and its grid.
    private let listSpacing: CGFloat = 20

    /// Measured height of a `CategoryHeader`. Headers are static, so this
    /// settles on the first layout pass and then stops changing.
    @State private var headerHeight: CGFloat = 0

    /// Distance below the top of the viewport at which a section takes over as
    /// "current". A section's grid begins one pinned `CategoryHeader` plus one
    /// `LazyVStack` spacing below its own header, so a grid crossing this line
    /// means that header has just reached the top edge.
    ///
    /// Measured rather than hardcoded, and biased a few points high on purpose:
    /// `scrollTo` parks a header exactly on this boundary, so a threshold even
    /// slightly *under* the resting value would resolve to the previous section
    /// and snap the pill backwards after every tap. Erring high only moves the
    /// switch a few points early, which is invisible against ~800pt sections.
    private var sectionSwitchOffset: CGFloat {
        headerHeight + listSpacing + 8
    }

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
                                            HapticManager.shared.selection()
                                            // Set flag to indicate user manually clicked, so the
                                            // sections the list passes on the way to the target
                                            // don't steal the selection back.
                                            isUserScrolling = true

                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                viewModel.selectCategory(category.id)
                                                // Scroll to the selected category. Centring the
                                                // pill is handled by the single `onChange` below.
                                                scrollProxy?.scrollTo(category.id, anchor: .top)
                                            }

                                            // Reset flag after animation completes
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                                isUserScrolling = false
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
                                        // `.id` sits on the header rather than the Section so
                                        // `scrollTo(category.id, anchor: .top)` has one
                                        // unambiguous target — modifiers on a Section are
                                        // spread across both its header and its content.
                                        Section(header: CategoryHeader(title: category.name)
                                            .background(
                                                GeometryReader { geo in
                                                    Color.clear.preference(
                                                        key: CategoryHeaderHeightKey.self,
                                                        value: geo.size.height
                                                    )
                                                }
                                            )
                                            .id(category.id)
                                        ) {
                                            CoursesGrid(courses: category.courses, viewModel: viewModel)
                                                .background(
                                                    GeometryReader { geo in
                                                        Color.clear.preference(
                                                            key: SectionOffsetKey.self,
                                                            value: [category.id: geo.frame(in: .named(scrollSpace)).minY]
                                                        )
                                                    }
                                                )
                                        }
                                    }

                                }

                                Spacer().frame(height: 100)
                            }
                            .coordinateSpace(name: scrollSpace)
                            .padding(.horizontal, 20)
                            .onPreferenceChange(CategoryHeaderHeightKey.self) { height in
                                headerHeight = height
                            }
                            .onPreferenceChange(SectionOffsetKey.self) { offsets in
                                syncSelectedCategory(with: offsets)
                            }
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
            // Single owner of the pill bar's horizontal position. Selection now
            // changes at most once per section boundary, so only one scroll
            // animation is ever in flight — previously every section the lazy
            // stack built started its own and they cut each other off mid-flight,
            // leaving the pill row parked between positions.
            .onChange(of: viewModel.selectedCategoryId) { newId in
                guard !newId.isEmpty else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    categoryScrollProxy?.scrollTo("pill_\(newId)", anchor: .center)
                }
            }
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
    
    /// Picks the category that currently owns the top of the list and keeps
    /// `selectedCategoryId` in step with it.
    ///
    /// Driven by measured positions, so it fires when a section is actually
    /// reached. The previous `Section.onAppear` trigger fired when SwiftUI
    /// *built* the section, which — with `pinnedViews` forcing headers to be
    /// materialised well ahead of their content — happened while the section
    /// was still a screen below the fold.
    private func syncSelectedCategory(with offsets: [String: CGFloat]) {
        // A pill tap (or deep link) is animating the list to a specific section;
        // the sections it passes on the way must not steal the selection.
        guard !isUserScrolling else { return }

        let ordered = viewModel.availableCategories

        // The deepest section whose grid has crossed the pinned-header line —
        // i.e. the one whose header is sitting at the top edge right now.
        // Sections the lazy stack hasn't built have no entry and are skipped.
        let current = ordered.last(where: { category in
            guard let minY = offsets[category.id] else { return false }
            return minY <= sectionSwitchOffset
        }) ?? ordered.first

        guard let current, current.id != viewModel.selectedCategoryId else { return }

        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.selectCategory(current.id)
        }
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

// MARK: - Section Offset Tracking

/// Each category section's vertical offset inside the course list, keyed by
/// category id, so the pill bar can follow what's actually on screen rather
/// than what SwiftUI happens to have built.
private struct SectionOffsetKey: PreferenceKey {
    static let defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

/// Height of a `CategoryHeader`, used to work out where a section's header sits
/// relative to the top of the list once it has pinned. Every header is a single
/// line in the same font, so `max` yields the one value they all share without
/// a reader needing to know which header it came from.
private struct CategoryHeaderHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
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
        .buttonStyle(ScalePressStyle())
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
                .buttonStyle(ScalePressStyle())
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
