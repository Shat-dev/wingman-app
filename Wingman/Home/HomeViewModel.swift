//
//  HomeViewModel.swift
//  Wingman
//

import Foundation
import Combine
import UIKit

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
    /// True while the initial daily-practice fetch is in flight. HomeView uses
    /// this to show a subtle indicator on the streak badge until the network
    /// response arrives. Header, motivational quote, and continue-course card
    /// render synchronously from cache and aren't gated by this flag — so
    /// there is no full-screen spinner and no added latency on the render path.
    @Published var isLoading: Bool = true
    
    // MARK: - UserDefaults Keys
    private static let lastAccessedCourseKey = "last_accessed_course_id"
    private static let dailyQuoteIndexKey = "daily_quote_current_index"
    private static let dailyQuoteDayKey = "daily_quote_last_day"
    private static let dailyQuoteShownKey = "daily_quote_shown_indices"
    
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
                log("📡 ========== NOTIFICATION RECEIVED ==========")
                log("📡 Daily practice completion notification received in HomeViewModel")
                log("📡 About to refresh daily practice status...")
                self?.refreshDailyPracticeStatus()
                log("📡 ==========================================")
            }
            .store(in: &cancellables)

        // Re-evaluate the daily quote on app foreground. Without this, a user
        // who backgrounds the app overnight keeps the previous day's cached
        // quote until cold launch, since the VM lives for the app session.
        // `loadMotivationalQuote()` is cheap and no-ops when the day hasn't
        // changed (cache hit on `dailyQuoteDayKey`).
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.loadMotivationalQuote()
            }
            .store(in: &cancellables)

        log("✅ Notification listener setup complete in HomeViewModel")
    }
    
    // MARK: - Load User Data
    func loadUserData() {
        log("📊 Loading user data...")

        // Previously read a UserDefaults key ("onboarding_name") that is never
        // written anywhere in the codebase — that branch always fell through
        // to "User". HomeView's header reads the name directly from the
        // Supabase auth session, so this property is only a fallback; we keep
        // the fallback value identical to the prior behavior ("User") to
        // guarantee no visible regression for anything reading viewModel.userName.
        userName = UserProfileStore.shared.displayName ?? "User"

        // Check if practiced today (legacy check for hasPracticeToday)
        if let lastPracticeDate = UserDefaults.standard.object(forKey: "last_practice_date") as? Date {
            hasPracticeToday = Calendar.current.isDateInToday(lastPracticeDate)
        }
        
        // Check daily practice completion status (this will also load the current streak)
        Task {
            await checkDailyPracticeCompletion()
        }
        
        log("✅ User data loaded:")
        log("   - Name: \(userName)")
        log("   - Practiced today: \(hasPracticeToday)")
    }
    
    // MARK: - Load Continue Course (Last course user was working on)
    func loadContinueCourse() {
        log("📚 Loading continue course...")
        
        // Get the last accessed course ID from UserDefaults
        guard let lastCourseId = UserDefaults.standard.string(forKey: HomeViewModel.lastAccessedCourseKey) else {
            log("⚠️ No last accessed course found")
            continueCourse = nil
            return
        }
        
        log("📖 Last accessed course ID: \(lastCourseId)")
        
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
            log("⚠️ Course not found for ID: \(lastCourseId)")
            continueCourse = nil
            return
        }

        // Safety net: if the last-accessed course is locked (either by the
        // hardcoded "coming soon" flag or by progression), never surface it
        // as the Continue card. Under normal flow CourseDetailSheet already
        // gates the save, so this is defensive.
        if isCourseLocked(course) {
            log("🔒 Last accessed course is locked — hiding Continue card")
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
        
        log("✅ Continue course loaded:")
        log("   - Category: \(categoryName)")
        log("   - Course: \(course.title)")
        log("   - Progress: \(Int(progressValue * 100))% (\(completedCount)/\(totalCount) lessons)")
    }
    
    // MARK: - Course Lock Check (matches CoursesViewModel derivation)
    /// Returns true if the given course is locked because the previous
    /// course in the same category hasn't been fully completed.
    private func isCourseLocked(_ course: Course) -> Bool {
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
        log("💾 Saved last accessed course: \(courseId)")
    }
    
    // MARK: - Load Motivational Quote
    //
    // Daily quote selection: one quote per calendar day, held constant across
    // relaunches within that day. Draws from an unseen pool stored in
    // UserDefaults — every quote is shown exactly once before any repeat, and
    // when the pool empties it resets to the full 120. Uses `yyyy-MM-dd` in the
    // device's current timezone as the day key (matching the rest of the app's
    // daily-boundary model).
    private func loadMotivationalQuote() {
        let quotes = Quotes.all
        guard !quotes.isEmpty else { return }

        let defaults = UserDefaults.standard
        let today = Self.currentDayKey()

        if defaults.string(forKey: Self.dailyQuoteDayKey) == today,
           let cachedIndex = defaults.object(forKey: Self.dailyQuoteIndexKey) as? Int,
           quotes.indices.contains(cachedIndex) {
            motivationalQuote = quotes[cachedIndex]
            return
        }

        var shown = Set(defaults.array(forKey: Self.dailyQuoteShownKey) as? [Int] ?? [])
        let allIndices = Set(quotes.indices)
        var pool = allIndices.subtracting(shown)
        if pool.isEmpty {
            // Cycle complete. Reset the shown set, but seed it with the most
            // recent index so we can't pick it again back-to-back across the
            // cycle boundary. It'll become eligible on the next cycle reset.
            shown.removeAll()
            if let recent = defaults.object(forKey: Self.dailyQuoteIndexKey) as? Int,
               quotes.indices.contains(recent) {
                shown.insert(recent)
            }
            pool = allIndices.subtracting(shown)
        }

        let nextIndex = pool.randomElement() ?? 0
        shown.insert(nextIndex)

        defaults.set(Array(shown), forKey: Self.dailyQuoteShownKey)
        defaults.set(nextIndex, forKey: Self.dailyQuoteIndexKey)
        defaults.set(today, forKey: Self.dailyQuoteDayKey)

        motivationalQuote = quotes[nextIndex]
    }

    private static func currentDayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter.string(from: Date())
    }
    
    // MARK: - Check Daily Practice Completion
    @MainActor
    private func checkDailyPracticeCompletion() async {
        defer { isLoading = false }
        do {
            log("🔄 Checking daily practice completion status...")
            let status = try await dailyPracticeService.getDailyPracticeStatus()

            // Update UI state based on status from database (using computed properties with defaults)
            isDailyPracticeCompleted = status.completedToday
            dailyPracticeButtonText = status.completedToday ? "Completed" : "Start"
            isDailyPracticeButtonEnabled = status.canContinue

            // Update streak from database (using computed property with default)
            let oldStreak = currentStreak
            currentStreak = status.streak

            // Mirror streak fields into the shared store so Profile (and the
            // on-disk cache) reflects this fetch without a second RPC call.
            StreakStore.shared.apply(status: status)

            log("✅ Daily practice status: \(status.completedToday ? "Completed" : "Not completed")")
            log("✅ Current streak UPDATED: \(oldStreak) → \(status.streak)")
            log("   - Button text: \(dailyPracticeButtonText)")
            log("   - Button enabled: \(isDailyPracticeButtonEnabled)")

        } catch {
            log("❌ Failed to check daily practice completion: \(error)")
            // On error, default to allowing start and use cached streak
            isDailyPracticeCompleted = false
            dailyPracticeButtonText = "Start"
            isDailyPracticeButtonEnabled = true

            // Fall back to the shared store's cached value (seeded from UserDefaults
            // on launch). Previously read a UserDefaults key that was never written,
            // which always returned 0.
            currentStreak = StreakStore.shared.currentStreak ?? 0
        }
    }
    
    // MARK: - Refresh Daily Practice Status (call this when returning from daily practice)
    func refreshDailyPracticeStatus() {
        log("🔄 refreshDailyPracticeStatus() called")
        Task {
            log("🔄 Starting async task to check daily practice completion...")
            await checkDailyPracticeCompletion()
            log("🔄 Async task completed")
        }
    }
    
    // MARK: - Actions
    func startPractice() {
        log("🏃 Starting daily practice...")
        // Navigation handled by view
    }
    
    func logApproach() {
        log("📝 Logging today's approach...")
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
