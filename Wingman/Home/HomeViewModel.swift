//
//  HomeViewModel.swift
//  Wingman
//

import Foundation
import Combine

// MARK: - Continue Course Model
struct ContinueCourse {
    let courseId: String
    let categoryName: String
    let courseName: String
    let thumbnailName: String
    let progress: Double  // 0.0 to 1.0
    let completedLessons: Int
    let totalLessons: Int
}

final class HomeViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var userName: String = ""
    @Published var currentStreak: Int = 0
    @Published var hasPracticeToday: Bool = false
    @Published var motivationalQuote: String = ""
    @Published var continueCourse: ContinueCourse? = nil
    
    // MARK: - UserDefaults Keys
    private static let lastAccessedCourseKey = "last_accessed_course_id"
    
    // MARK: - Services
    private let client = SupabaseManager.shared.client
    
    // MARK: - Init
    init() {
        loadUserData()
        loadMotivationalQuote()
        loadContinueCourse()
    }
    
    // MARK: - Load User Data
    func loadUserData() {
        print("📊 Loading user data...")
        
        // Get user name from UserDefaults (from onboarding)
        if let name = UserDefaults.standard.string(forKey: "onboarding_name"), !name.isEmpty {
            userName = name
        } else {
            userName = "User"
        }
        
        // Load streak from UserDefaults
        currentStreak = UserDefaults.standard.integer(forKey: "current_streak")
        
        // Check if practiced today
        if let lastPracticeDate = UserDefaults.standard.object(forKey: "last_practice_date") as? Date {
            hasPracticeToday = Calendar.current.isDateInToday(lastPracticeDate)
        }
        
        print("✅ User data loaded:")
        print("   - Name: \(userName)")
        print("   - Streak: \(currentStreak)")
        print("   - Practiced today: \(hasPracticeToday)")
    }
    
    // MARK: - Load Continue Course (Last course user was working on)
    func loadContinueCourse() {
        print("📚 Loading continue course...")
        
        // Get the last accessed course ID from UserDefaults
        guard let lastCourseId = UserDefaults.standard.string(forKey: HomeViewModel.lastAccessedCourseKey) else {
            print("⚠️ No last accessed course found")
            continueCourse = nil
            return
        }
        
        print("📖 Last accessed course ID: \(lastCourseId)")
        
        // Find the course from CourseCategory.dummyCategories
        var foundCourse: Course?
        var foundCategoryName: String?
        
        for category in CourseCategory.dummyCategories {
            if let course = category.courses.first(where: { $0.id == lastCourseId }) {
                foundCourse = course
                foundCategoryName = category.name
                break
            }
        }
        
        guard let course = foundCourse, let categoryName = foundCategoryName else {
            print("⚠️ Course not found for ID: \(lastCourseId)")
            continueCourse = nil
            return
        }
        
        // Calculate progress for the course
        let progress = LessonDataService.shared.loadLessonProgress(courseId: lastCourseId)
        let lessons = LessonDataService.shared.loadLessonsForCourse(courseId: lastCourseId)
        
        let completedCount = progress.completed.count
        let totalCount = lessons.count > 0 ? lessons.count : course.lessonsCount
        let progressValue = totalCount > 0 ? Double(completedCount) / Double(totalCount) : 0.0
        
        // Get the actual thumbnail image name
        let thumbnailImageName = getThumbnailImageName(for: course.thumbnailName)
        
        continueCourse = ContinueCourse(
            courseId: lastCourseId,
            categoryName: categoryName,
            courseName: course.title,
            thumbnailName: thumbnailImageName,
            progress: progressValue,
            completedLessons: completedCount,
            totalLessons: totalCount
        )
        
        print("✅ Continue course loaded:")
        print("   - Category: \(categoryName)")
        print("   - Course: \(course.title)")
        print("   - Progress: \(Int(progressValue * 100))% (\(completedCount)/\(totalCount) lessons)")
    }
    
    // MARK: - Get Thumbnail Image Name
    private func getThumbnailImageName(for thumbnailName: String) -> String {
        // Map Course thumbnailName to actual image assets
        let mapping: [String: String] = [
            // Mindset & Foundations
            "course_beliefs": "beliefandreframes",
            "course_fear": "fearandexposure",
            "course_presence": "presenceandexpresions",
            "course_stability": "innerstability",
            "course_nonnegotiables": "nonnegotiables",
            
            // Approach Mechanics
            "course_readiness": "approachreadiness",
            "course_physical": "thephysicalapproch",
            "course_opener": "theopner",
            "course_reading": "readingandresponding",
            "course_situational": "situationspecficapproaches",
            "course_advanced": "advanceopeningtechniques",
            
            // Conversation Flow
            "course_smalltalk": "smalltalkandmomentum",
            "course_listening": "ListeningandAttunement",
            "course_vulnerability": "Sharing&Vulnerability",
            "course_closing": "advancedconversationskills",
            "course_advconvo": "advancedconversationskills",
            
            // Flirting & Chemistry
            "course_flirtprereq": "FlirtingPrerequisites",
            "course_playfulness": "Playfulness&Spark",
            "course_compliments": "Compliments&VerbalChemistry",
            "course_physical_presence": "PhysicalPresence&Escalation",
            "course_advflirt": "advancedFlirtingSkills",
            
            // Integration & Mastery
            "course_lifestyle": "Upgradingyourlifestyle",
            "course_opportunities": "CreatingOpportunties",
            "course_mastery": "Mastery&Identity",
            "course_selfdiscovery": "Learning&SelfDiscovery"
        ]
        
        return mapping[thumbnailName] ?? thumbnailName
    }
    
    // MARK: - Save Last Accessed Course (STATIC - call from anywhere)
    static func saveLastAccessedCourse(courseId: String) {
        UserDefaults.standard.set(courseId, forKey: lastAccessedCourseKey)
        UserDefaults.standard.synchronize()
        print("💾 Saved last accessed course: \(courseId)")
    }
    
    // MARK: - Load Motivational Quote
    private func loadMotivationalQuote() {
        let quotes = [
            "Each small approach restores your confidence.",
            "Confidence is built one conversation at a time.",
            "Every approach is a step toward growth.",
            "The regret of inaction outweighs the fear of rejection.",
            "Your future self will thank you for today's courage."
        ]
        
        motivationalQuote = quotes.randomElement() ?? quotes[0]
    }
    
    // MARK: - Actions
    func startPractice() {
        print("🏃 Starting daily practice...")
        // Navigation handled by view
    }
    
    func logApproach() {
        print("📝 Logging today's approach...")
        // Navigation handled by view
    }
    
    // MARK: - Update Streak
    func incrementStreak() {
        currentStreak += 1
        UserDefaults.standard.set(currentStreak, forKey: "current_streak")
        UserDefaults.standard.set(Date(), forKey: "last_practice_date")
        hasPracticeToday = true
    }
}
