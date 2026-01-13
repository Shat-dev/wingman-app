//
//  CoursesView.swift
//  Wingman
//

import SwiftUI

struct CoursesView: View {
    @StateObject private var viewModel = CoursesViewModel()
    @State private var selectedCourse: Course? = nil
    @State private var scrollProxy: ScrollViewProxy? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                if viewModel.isLoading {
                    // Loading state
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Loading courses...")
                            .font(.manropeRegular(size: 14))
                            .foregroundColor(.gray)
                            .padding(.top, 12)
                    }
                } else {
                    VStack(spacing: 0) {
                        
                        // MARK: - Header
                        Text("Courses")
                            .font(.manropeSemiBold(size: 20))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 16)
                        
                        // MARK: - Category Pills
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(viewModel.availableCategories) { category in
                                    CategoryPill(
                                        title: category.name,
                                        isSelected: viewModel.selectedCategoryId == category.id
                                    ) {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            viewModel.selectCategory(category.id)
                                            // Scroll to the selected category
                                            scrollProxy?.scrollTo(category.id, anchor: .top)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .padding(.bottom, 20)
                        
                        // MARK: - All Courses (Scrollable)
                        ScrollViewReader { proxy in
                            ScrollView(showsIndicators: false) {
                                LazyVStack(alignment: .leading, spacing: 20, pinnedViews: [.sectionHeaders]) {
                                    ForEach(viewModel.availableCategories) { category in
                                        Section(header: CategoryHeader(title: category.name)) {
                                            CoursesGrid(
                                                courses: category.courses,
                                                onCourseTap: { course in
                                                    viewModel.selectCourse(course)
                                                    selectedCourse = course
                                                }
                                            )
                                        }
                                        .id(category.id)
                                    }
                                }
                                .padding(.horizontal, 20)
                                
                                Spacer().frame(height: 100)
                            }
                            .onAppear {
                                scrollProxy = proxy
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedCourse) { course in
                CourseDetailSheet(course: course)
            }
            .onAppear {
                print("👁️ CoursesView appeared")
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
                .foregroundColor(isSelected ? .black : .gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected ? Color.white : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(isSelected ? Color.black : Color.gray.opacity(0.3), lineWidth: 1)
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
            .foregroundColor(.black)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .background(Color.white)
    }
}

// MARK: - Courses Grid
struct CoursesGrid: View {
    let courses: [Course]
    let onCourseTap: (Course) -> Void
    
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(courses) { course in
                CourseCard(course: course) {
                    onCourseTap(course)
                }
            }
        }
    }
}

// MARK: - Course Card
struct CourseCard: View {
    let course: Course
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                
                // Thumbnail with illustration
                ZStack {
                    Rectangle()
                        .fill(Color(.white))
                        .frame(height: 200)
                    
                    Image(getImageForCourse())
                        .resizable()
                        .scaledToFit()
                        
                }
                Divider()
                    .background(Color.gray.opacity(0.2))
                // Title section with padding
                VStack(alignment: .leading, spacing: 0) {
                    Text(course.title)
                        .font(.manropeRegular(size: 16))
                        .foregroundColor(.black)
                        .lineSpacing(2)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
            }
            .background(Color.white)
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func getImageForCourse() -> String {
        // Map course titles to SF Symbols
        let title = course.title.lowercased()
        
        //Mindset & Foundations
        if title.contains("belief") { return "beliefandreframes" }
        if title.contains("fear") { return "fearandexposure" }
        if title.contains("presence") { return "presenceandexpresions" }
        if title.contains("stability") { return "innerstability" }
        if title.contains("non-negotiable") { return "nonnegotiables" }
        //Approach Mechanics
        if title.contains("readiness") { return "approachreadiness" }
        if title.contains("physical") { return "thephysicalapproch" }
        if title.contains("opener") { return "theopner" }
        if title.contains("reading") { return "readingandresponding" }
        if title.contains("situational") { return "situationspecficapproaches" }
        if title.contains("advanced") { return "advanceopeningtechniques" }
        //conversation flow
        if title.contains("small talk") { return "smalltalkandmomentum" }
        if title.contains("listening") { return "ListeningandAttunement" }
        if title.contains("vulnerability") { return "Sharing&Vulnerability" }
        if title.contains("closing") { return "advancedconversationskills" }
        if title.contains("conversation") { return "advancedconversationskills"}
        //Flirting & Chemistry
        if title.contains("flirting") { return "FlirtingPrerequisites" }
        if title.contains("playfulness") { return "Playfulness&Spark" }
        if title.contains("compliment") { return "Compliments&VerbalChemistry" }
        if title.contains("chemistry") { return "PhysicalPresence&Escalation" }
        if title.contains("flirting") { return "advancedFlirtingSkills" }
        //Integration & Mastery
        if title.contains("upgrading") { return "Upgradingyourlifestyle" }
        if title.contains("creating") { return "CreatingOpportunties" }
        if title.contains("mastery") { return "Mastery&Identity" }
        if title.contains("learning") { return "Learning&SelfDiscovery" }
        
        return "book"
    }
}

#Preview {
    CoursesView()
}
