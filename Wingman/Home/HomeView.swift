//
//  HomeView.swift
//  Wingman
//

import SwiftUI
import Auth
import Supabase

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @State private var navigateToPractice = false
    @State private var showLogApproachSheet = false
    @State private var selectedCourse: Course? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // MARK: - Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Good Morning,")
                                .font(.manropeMedium(size: 24))
                                .foregroundColor(.black)
                            
                            // Show user name like Dashboard (from Supabase userMetadata["display_name"])
                            if let user = SupabaseManager.shared.client.auth.currentUser {
                                let name = user.userMetadata["display_name"]?.stringValue
                                
                                if let name = name, !name.isEmpty {
                                    Text(name)
                                        .font(.manropeMedium(size: 24))
                                        .foregroundColor(.black)
                                } else if let email = user.email, !email.isEmpty {
                                    Text(email)
                                        .font(.manropeMedium(size: 24))
                                        .foregroundColor(.black)
                                } else {
                                    Text("User")
                                        .font(.manropeMedium(size: 24))
                                        .foregroundColor(.black)
                                }
                            } else {
                                Text("User")
                                    .font(.manropeMedium(size: 24))
                                    .foregroundColor(.black)
                            }
                        }
                        
                        Spacer()
                        
                        // MARK: - Streak Badge
                        HStack(spacing: 6) {
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

                                    Button("Start") {
                                        navigateToPractice = true
                                    }
                                    .font(.manropeSemiBold(size: 16))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(Color.black)
                                    .cornerRadius(5)
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
                            HStack(alignment: .top, spacing: 10) {
                                Image("quote_sign")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                    .padding(.top, -30)

                                Text(viewModel.motivationalQuote)
                                    .font(.georgiaItalic(size: 16))
                                    .foregroundColor(Color.black.opacity(0.75))
                                    .multilineTextAlignment(.leading)
                                    .lineSpacing(3)
                                    .padding(.top, 6)

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 20)
                            
                            // MARK: - Continue Section (Single Course - Only show if course exists)
                            if let course = viewModel.continueCourse {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Continue")
                                        .font(.manropeSemiBold(size: 18))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 20)
                                    
                                    // Continue Course Card - Pixel Perfect Design
                                    ContinueCourseCard(course: course) {
                                        // Find the actual Course object and navigate
                                        selectedCourse = findCourse(courseId: course.courseId)
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            
                            // MARK: - Your Modules Section
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Your Modules")
                                    .font(.manropeSemiBold(size: 18))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 20)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ModuleCard(
                                            title: "Mindset & Foundations",
                                            subtitle: "Suggested",
                                            illustration: "module_illust_1"
                                        )
                                        
                                        ModuleCard(
                                            title: "Body Language",
                                            subtitle: "Popular",
                                            illustration: "module_illust_2"
                                        )
                                        
                                        ModuleCard(
                                            title: "Conversation Skills",
                                            subtitle: "New",
                                            illustration: "module_illust_3"
                                        )
                                    }
                                    .padding(.horizontal, 20)
                                }
                            }
                            
                            Spacer().frame(height: 100)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .navigationBarHidden(true)
            .background(
                // Hidden NavigationLink to support iOS 16+ navigation to CourseDetailSheet
                Group {
                    if let selected = selectedCourse {
                        NavigationLink(
                            destination: CourseDetailSheet(course: selected)
                                .onDisappear { selectedCourse = nil },
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
                    } else {
                        EmptyView()
                    }
                }
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
                viewModel.loadContinueCourse()  // IMPORTANT: Refresh on every appear
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

// MARK: - Continue Course Card (Pixel Perfect - Matches Screenshot)
struct ContinueCourseCard: View {
    let course: ContinueCourse
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // MARK: - Left: Square Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                    
                    Image(course.thumbnailName)
                        .resizable()
                        .scaledToFit()
                        .padding(8)
                }
                .frame(width: 100, height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.15), lineWidth: 1)
                )
                
                // MARK: - Right: Content
                VStack(alignment: .leading, spacing: 0) {
                    // Title: "Category: Course Name"
                    Text("\(course.categoryName): \(course.courseName)")
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(.black)
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
                                    .fill(Color.black)
                                    .frame(width: geometry.size.width * course.progress, height: 4)
                            }
                        }
                        .frame(height: 4)
                        
                        // Percentage
                        Text("\(Int(course.progress * 100))%")
                            .font(.manropeMedium(size: 14))
                            .foregroundColor(Color(hex: "888888"))
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                .padding(.vertical, 12)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 132)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Module Card
struct ModuleCard: View {
    let title: String
    let subtitle: String
    let illustration: String
    
    var body: some View {
        VStack(spacing: 16) {
            
            // Illustration
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.05))
                    .frame(height: 200)
                
                // Placeholder illustration
                Image(systemName: "person.2")
                    .font(.system(size: 60))
                    .foregroundColor(.gray.opacity(0.3))
            }
            
            VStack(spacing: 8) {
                // Title
                Text(title)
                    .font(.manropeSemiBold(size: 15))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Subtitle
                Text(subtitle)
                    .font(.manropeRegular(size: 12))
                    .foregroundColor(.gray)
                
                // Open Button
                Button(action: {
                    // Open module
                }) {
                    Text("Open")
                        .font(.manropeSemiBold(size: 14))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.black)
                        .cornerRadius(5)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(width: 240)
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
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
    HomeView()
}
