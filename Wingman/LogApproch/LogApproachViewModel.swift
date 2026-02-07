//
//  LogApproachViewModel.swift
//  Wingman
//

import Foundation
import Combine
import Supabase

final class LogApproachViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var selectedLevel: Int = 2 // Default: Level 2
    @Published var anxietyLevel: Double = 5.0 // Range: 1-10
    @Published var title: String = "" // NEW: Title field for the approach
    @Published var notes: String = ""
    @Published var isSaving: Bool = false
    @Published var showSuccess: Bool = false
    @Published var errorMessage: String = ""
    
    // MARK: - Data
    let levels = [
        ApproachLevel(number: 1, title: "Social Warm-up"),
        ApproachLevel(number: 2, title: "Extended Conversation"),
        ApproachLevel(number: 3, title: "Indirect Approach"),
        ApproachLevel(number: 4, title: "Direct Approach")
    ]
    
    let placeholderText = "Congratulations! How did you feel? What was the situation? How did it go for you?"
    
    // MARK: - Services
    private let client = SupabaseManager.shared.client
    
    // MARK: - Computed Properties
    var canSave: Bool {
        // Must have at least a title and valid level
        return !title.trimmingCharacters(in: .whitespaces).isEmpty
            && selectedLevel >= 1
            && selectedLevel <= 4
    }
    
    var anxietyLevelText: String {
        let descriptions = [
            1: "Very anxious",
            2: "Anxious",
            3: "Slightly nervous",
            4: "Moderate anxiety",
            5: "Neutral",
            6: "Somewhat confident",
            7: "Confident",
            8: "Very confident",
            9: "Extremely confident",
            10: "Very confident"
        ]
        
        let level = Int(anxietyLevel.rounded())
        return descriptions[level] ?? "Moderate"
    }
    
    // MARK: - Actions
    func selectLevel(_ level: Int) {
        print("📝 Selected approach level: \(level)")
        print("   - Level name: \(levels[level - 1].title)")
        selectedLevel = level
    }
    
    func updateAnxietyLevel(_ value: Double) {
        anxietyLevel = value
        print("😰 Confidence level updated: \(Int(value))/10 - \(anxietyLevelText)")
    }
    
    func showInfoSheet() {
        print("ℹ️ Info button tapped - Show approach levels guide")
    }
    
    func saveApproach() {
        guard canSave else {
            print("❌ Cannot save - validation failed")
            errorMessage = "Please provide a title for your encounter"
            return
        }
        
        print("\n💾 Saving approach log...")
        print("   - Title: \(title)")
        print("   - Level: \(selectedLevel) - \(levels[selectedLevel - 1].title)")
        print("   - Confidence: \(Int(anxietyLevel))/10 - \(anxietyLevelText)")
        print("   - Notes: \(notes.isEmpty ? "(empty)" : notes)")
        
        isSaving = true
        errorMessage = ""
        
        Task {
            do {
                try await saveToSupabase()
                
                await MainActor.run {
                    self.isSaving = false
                    self.showSuccess = true
                    print("✅ Approach saved successfully!")
                    
                    // Auto-hide success after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.showSuccess = false
                    }
                    
                    // Reset form
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        self.resetForm()
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.isSaving = false
                    self.errorMessage = "Failed to save. Please try again."
                    print("❌ Error saving approach: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Save to Supabase
    private func saveToSupabase() async throws {
        guard let userId = getUserId() else {
            throw NSError(domain: "LogApproach", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }
        
        struct ApproachLog: Codable {
            let userId: String
            let title: String
            let approachLevel: Int
            let anxietyLevel: Int
            let notes: String?
            let loggedAt: String
            
            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
                case title
                case approachLevel = "approach_level"
                case anxietyLevel = "anxiety_level"
                case notes
                case loggedAt = "logged_at"
            }
        }
        
        let log = ApproachLog(
            userId: userId,
            title: title,
            approachLevel: selectedLevel,
            anxietyLevel: Int(anxietyLevel),
            notes: notes.isEmpty ? nil : notes,
            loggedAt: ISO8601DateFormatter().string(from: Date())
        )
        
        print("📤 Sending to Supabase:")
        print("   - User ID: \(userId)")
        print("   - Title: \(log.title)")
        print("   - Level: \(log.approachLevel)")
        print("   - Confidence: \(log.anxietyLevel)")
        
        try await client
            .from("approach_logs")
            .insert(log)
            .execute()
        
        print("✅ Successfully inserted into database")
        
        // Refresh the shared approach service to update UI
        await ApproachService.shared.fetchApproaches()
        
        // Update streak and stats
        updateUserStats()
    }
    
    private func updateUserStats() {
        // Update practice date and streak
        UserDefaults.standard.set(Date(), forKey: "last_practice_date")
        
        // Increment approach count
        let currentCount = UserDefaults.standard.integer(forKey: "total_approaches")
        UserDefaults.standard.set(currentCount + 1, forKey: "total_approaches")
        
        print("📊 Stats updated:")
        print("   - Total approaches: \(currentCount + 1)")
    }
    
    private func resetForm() {
        title = ""
        selectedLevel = 2
        anxietyLevel = 5.0
        notes = ""
        print("🔄 Form reset to defaults")
    }
    
    private func getUserId() -> String? {
        return UserDefaults.standard.string(forKey: "current_user_id")
    }
}

// MARK: - Approach Level Model
struct ApproachLevel: Identifiable {
    let id = UUID()
    let number: Int
    let title: String
}
