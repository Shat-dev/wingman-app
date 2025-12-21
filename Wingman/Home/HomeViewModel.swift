//
//  HomeViewModel.swift
//  Wingman
//

import Foundation
import Combine

final class HomeViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var userName: String = ""
    @Published var currentStreak: Int = 0
    @Published var hasPracticeToday: Bool = false
    @Published var motivationalQuote: String = ""
    
    // MARK: - Services
    private let client = SupabaseManager.shared.client
    
    // MARK: - Init
    init() {
        loadUserData()
        loadMotivationalQuote()
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
