//
//  HomeView.swift
//  Wingman
//

import SwiftUI
import Auth
import Supabase

struct HomeView: View {
    // Binding added so Home can change the selected tab in MainTabView
    @Binding var selectedTab: Int
    @EnvironmentObject private var coursesRouter: CoursesRouter

    @StateObject private var viewModel = HomeViewModel()
    @State private var navigateToPractice = false
    @State private var showLogApproachSheet = false
    @State private var selectedCourse: Course? = nil
    @State private var currentModulePage: Int = 0
    
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
                                .foregroundColor(.black)
                            
                            // Show user name like Dashboard (from Supabase userMetadata["display_name"])
                            if let user = SupabaseManager.shared.client.auth.currentUser {
                                let name = user.userMetadata["display_name"]?.stringValue
                                
                                if let name = name, !name.isEmpty {
                                    Text(name)
                                        .font(.manropeMedium(size: 24))
                                        .foregroundColor(Color(hex: "1A1A1A").opacity(0.7))
                                } else if let email = user.email, !email.isEmpty {
                                    Text(email)
                                        .font(.manropeMedium(size: 24))
                                        .foregroundColor(Color(hex: "1A1A1A").opacity(0.7))
                                } else {
                                    Text("User")
                                        .font(.manropeMedium(size: 24))
                                        .foregroundColor(Color(hex: "1A1A1A").opacity(0.7))
                                }
                            } else {
                                Text("User")
                                    .font(.manropeMedium(size: 24))
                                    .foregroundColor(Color(hex: "1A1A1A").opacity(0.7))
                            }
                        }
                        
                        Spacer()
                        
                        // MARK: - Streak Badge
                        HStack(spacing: 2) {
                            Image("flame")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 16, height: 16)
                                .padding(.leading, 16)

                            Text("\(viewModel.currentStreak)")
                                .font(.manropeMedium(size: 20))
                                .padding(.trailing, 16)
                        }
                        .foregroundColor(.black)
                        .frame(width: 64, height: 44)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.black.opacity(0.15), lineWidth: 1)
                        )
                        .cornerRadius(5)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            
                            // MARK: - Daily Practice Card
                            VStack(spacing: 0) {
                                VStack(spacing: 0) {
                                    Text("Daily Practice")
                                        .font(.manropeMedium(size: 20))
                                        .foregroundColor(.black)
                                        .padding(.top, 20)
                                        .frame(maxWidth: .infinity)

                                    Text("Suggested")
                                        .font(.manropeMedium(size: 14))
                                        .foregroundColor(.gray)
                                        .padding(.top, 8)
                                        .frame(maxWidth: .infinity)

                                    Button(action: {
                                        navigateToPractice = true
                                    }) {
                                        Text("Start")
                                            .font(.manropeSemiBold(size: 16))
                                            .foregroundColor(.white)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 52)
                                            .background(Color.black)
                                            .cornerRadius(5)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
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
                                Image("wingman_logo")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 300, height: 280)
                                    .opacity(0.12)
                                    .padding(.top, -100)
                                    .padding(.trailing, 155),
                                alignment: .topTrailing
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
                                        .foregroundColor(.black)

                                    Text("Log Encounter")
                                        .font(.manropeSemiBold(size: 16))
                                        .foregroundColor(.black)
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 5)
                                        .stroke(Color.black.opacity(0.35), lineWidth: 1)
                                )
                                .cornerRadius(5)
                            }
                            .padding(.horizontal, 20)
                            
                            Divider().background(Color.gray.opacity(0.2))
                            
                            
                            // MARK: - Motivational Quote
                            VStack(alignment: .leading, spacing: 10) {
                                Image("quote_sign")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)


                                Text(viewModel.motivationalQuote)
                                    .font(.georgiaItalic(size: 16))
                                    .foregroundColor(Color.black.opacity(0.75))
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
                                        .foregroundColor(.black)
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
                                    .foregroundColor(.black)
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
                }
            }
            .navigationBarHidden(true)
            // Hidden navigation link to push CourseDetailSheet when selectedCourse is set
            .background(
                NavigationLink(
                    destination: selectedCourse.map { CourseDetailSheet(course: $0) },
                    isActive: Binding(
                        get: { selectedCourse != nil },
                        set: { isActive in
                            if !isActive { selectedCourse = nil }
                        }
                    )
                ) {
                    EmptyView()
                }
                .hidden()
            )
            .navigationDestination(isPresented: $navigateToPractice) {
                DailyPracticeView()
            }
            .sheet(isPresented: $showLogApproachSheet) {
                LogApproachBottomSheet(isPresented: $showLogApproachSheet)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                    .presentationCornerRadius(20)
            }
            .onAppear {
                print("👁️ HomeView appeared - refreshing continue course")
                viewModel.loadUserData()
                viewModel.loadContinueCourse()
            }
        }
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
    
    // Layout constants
    private let cardSpacing: CGFloat = 12
    private let horizontalPadding: CGFloat = 20
    private let peekAmount: CGFloat = 40  // How much of next card to show
    
    private var cardWidth: CGFloat {
        screenWidth - horizontalPadding - peekAmount - cardSpacing
    }
    
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
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let threshold = calculatedCardWidth / 3
                            let predictedOffset = value.predictedEndTranslation.width
                            
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                if predictedOffset < -threshold && currentPage < modules.count - 1 {
                                    currentPage += 1
                                } else if predictedOffset > threshold && currentPage > 0 {
                                    currentPage -= 1
                                }
                                dragOffset = 0
                            }
                        }
                )
                .onAppear {
                    screenWidth = width
                }
            }
            .frame(height: 430) // Cards only
            
            // Page Indicators - OUTSIDE GeometryReader
            HStack(spacing: 8) {
                ForEach(0..<modules.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.black : Color.gray.opacity(0.3))
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
                    .foregroundColor(.black)
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
                        .background(Color.black)
                        .cornerRadius(5)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color.white)
        .cornerRadius(5)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Continue Course Card (Pixel Perfect - Matches Screenshot)
struct ContinueCourseCard: View {
    let course: ContinueCourse
    let onTap: () -> Void
    
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
                        .foregroundColor(.black)
                        .lineSpacing(4)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading,20)
                    
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
                                    .fill(Color.black)
                                    .frame(width: geometry.size.width * course.progress, height: 4)
                            }
                        }
                        .frame(height: 4)
                        .padding(.leading,20)
                        
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
            .frame(height: 132)
            .background(Color.white)
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
}
