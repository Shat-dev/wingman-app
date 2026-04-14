//
//  HomeViewModel.swift
//  Wingman
//

import Foundation
import Combine

// MARK: - Notification Names
extension Notification.Name {
    static let dailyPracticeCompleted = Notification.Name("dailyPracticeCompleted")
}

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
    @Published var isDailyPracticeCompleted: Bool = false
    @Published var dailyPracticeButtonText: String = "Start"
    @Published var isDailyPracticeButtonEnabled: Bool = true
    
    // MARK: - UserDefaults Keys
    private static let lastAccessedCourseKey = "last_accessed_course_id"
    
    // MARK: - Services
    private let client = SupabaseManager.shared.client
    private let dailyPracticeService: DailyPracticeServiceProtocol = DailyPracticeService()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    init() {
        loadUserData()
        loadMotivationalQuote()
        loadContinueCourse()
        setupNotifications()
    }
    
    // MARK: - Notification Setup
    private func setupNotifications() {
        // Listen for daily practice completion notification
        NotificationCenter.default.publisher(for: .dailyPracticeCompleted)
            .sink { [weak self] _ in
                print("📡 ========== NOTIFICATION RECEIVED ==========")
                print("📡 Daily practice completion notification received in HomeViewModel")
                print("📡 About to refresh daily practice status...")
                self?.refreshDailyPracticeStatus()
                print("📡 ==========================================")
            }
            .store(in: &cancellables)
        print("✅ Notification listener setup complete in HomeViewModel")
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
        
        // Check if practiced today (legacy check for hasPracticeToday)
        if let lastPracticeDate = UserDefaults.standard.object(forKey: "last_practice_date") as? Date {
            hasPracticeToday = Calendar.current.isDateInToday(lastPracticeDate)
        }
        
        // Check daily practice completion status (this will also load the current streak)
        Task {
            await checkDailyPracticeCompletion()
        }
        
        print("✅ User data loaded:")
        print("   - Name: \(userName)")
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

        // Safety net: if the last-accessed course is locked (either by the
        // hardcoded "coming soon" flag or by progression), never surface it
        // as the Continue card. Under normal flow CourseDetailSheet already
        // gates the save, so this is defensive.
        if isCourseLocked(course) {
            print("🔒 Last accessed course is locked — hiding Continue card")
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
    
    // MARK: - Course Lock Check (matches CoursesViewModel derivation)
    /// Returns true if the given course is effectively locked — either by
    /// the hardcoded "coming soon" flag, or because the previous course in
    /// the same category hasn't been fully completed.
    private func isCourseLocked(_ course: Course) -> Bool {
        // Hardcoded hard gate ("coming soon").
        if course.isLocked { return true }

        // Progression gate: find the previous course in the same category.
        guard let category = CourseCategory.dummyCategories.first(where: { $0.id == course.categoryId }) else {
            return false
        }
        let sorted = category.courses.sorted { $0.displayOrder < $1.displayOrder }
        guard let idx = sorted.firstIndex(where: { $0.id == course.id }), idx > 0 else {
            return false // first course in the category — always unlocked
        }
        let previous = sorted[idx - 1]
        return !LessonDataService.shared.isCourseCompleted(courseId: previous.id)
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
    
    // MARK: - Check Daily Practice Completion
    @MainActor
    private func checkDailyPracticeCompletion() async {
        do {
            print("🔄 Checking daily practice completion status...")
            let status = try await dailyPracticeService.getDailyPracticeStatus()
            
            // Update UI state based on status from database (using computed properties with defaults)
            isDailyPracticeCompleted = status.completedToday
            dailyPracticeButtonText = status.completedToday ? "Completed" : "Start"
            isDailyPracticeButtonEnabled = status.canContinue
            
            // Update streak from database (using computed property with default)
            let oldStreak = currentStreak
            currentStreak = status.streak
            
            print("✅ Daily practice status: \(status.completedToday ? "Completed" : "Not completed")")
            print("✅ Current streak UPDATED: \(oldStreak) → \(status.streak)")
            print("   - Button text: \(dailyPracticeButtonText)")
            print("   - Button enabled: \(isDailyPracticeButtonEnabled)")
            
        } catch {
            print("❌ Failed to check daily practice completion: \(error)")
            // On error, default to allowing start and use cached streak
            isDailyPracticeCompleted = false
            dailyPracticeButtonText = "Start"
            isDailyPracticeButtonEnabled = true
            
            // Try to use cached streak from UserDefaults as fallback
            currentStreak = UserDefaults.standard.integer(forKey: "current_streak")
        }
    }
    
    // MARK: - Refresh Daily Practice Status (call this when returning from daily practice)
    func refreshDailyPracticeStatus() {
        print("🔄 refreshDailyPracticeStatus() called")
        Task {
            print("🔄 Starting async task to check daily practice completion...")
            await checkDailyPracticeCompletion()
            print("🔄 Async task completed")
        }
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
    
    // MARK: - Update Streak (Legacy - now handled by database)
    func incrementStreak() {
        // Legacy method - streak is now managed by database
        // Just refresh status to get latest streak from database
        refreshDailyPracticeStatus()
        
        // Keep legacy UserDefaults for backward compatibility
        UserDefaults.standard.set(Date(), forKey: "last_practice_date")
        hasPracticeToday = true
    }
}
