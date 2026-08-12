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
    
    // MARK: - Edit Mode Properties
    private var editingApproachId: UUID? = nil
    var isEditMode: Bool { editingApproachId != nil }
    
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
        // Must have at least a title, valid level, and notes within character limit
        return !title.trimmingCharacters(in: .whitespaces).isEmpty
            && selectedLevel >= 1
            && selectedLevel <= 4
            && notes.count <= 400
    }
    
    var saveButtonTitle: String {
        return isEditMode ? "Update Approach" : "Log Approach"
    }
    
    var headerTitle: String {
        return isEditMode ? "Edit Approach" : "Log Approach"
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
    
    // MARK: - Setup for Editing
    func setupForEditing(_ approach: ApproachLog) {
        log("📝 Setting up ViewModel for editing approach: \(approach.title)")
        editingApproachId = approach.id
        title = approach.title
        notes = approach.description
        selectedLevel = approach.level
        anxietyLevel = Double(approach.anxietyLevel)
        
        log("   - Title: \(title)")
        log("   - Level: \(selectedLevel)")
        log("   - Anxiety: \(anxietyLevel)")
        log("   - Notes: \(notes)")
    }
    
    // MARK: - Reset for New Entry
    func setupForNewEntry() {
        log("📝 Setting up ViewModel for new approach entry")
        editingApproachId = nil
        resetForm()
    }

    // MARK: - Actions
    func selectLevel(_ level: Int) {
        HapticManager.shared.selection()
        log("📝 Selected approach level: \(level)")
        log("   - Level name: \(levels[level - 1].title)")
        selectedLevel = level
    }
    
    func updateAnxietyLevel(_ value: Double) {
        anxietyLevel = value
        log("😰 Confidence level updated: \(Int(value))/10 - \(anxietyLevelText)")
    }
    
    func showInfoSheet() {
        log("ℹ️ Info button tapped - Show approach levels guide")
    }
    
    func saveApproach() {
        guard canSave else {
            log("❌ Cannot save - validation failed")
            errorMessage = "Please provide a title for your approach"
            return
        }
        
        if isEditMode {
            log("\n📝 Updating approach log...")
            log("   - ID: \(editingApproachId?.uuidString ?? "Unknown")")
        } else {
            log("\n💾 Saving new approach log...")
        }
        
        log("   - Title: \(title)")
        log("   - Level: \(selectedLevel) - \(levels[selectedLevel - 1].title)")
        log("   - Confidence: \(Int(anxietyLevel))/10 - \(anxietyLevelText)")
        log("   - Notes: \(notes.isEmpty ? "(empty)" : notes)")
        
        isSaving = true
        errorMessage = ""
        
        Task {
            do {
                // The new row's id is generated client-side so it can be used
                // as the XP `source_id` without a second round trip — the
                // insert below does not return the row.
                let newApproachId: UUID?
                if isEditMode {
                    try await updateInSupabase()
                    newApproachId = nil
                } else {
                    newApproachId = try await saveToSupabase()
                }

                await MainActor.run {
                    self.isSaving = false
                    self.showSuccess = true
                    HapticManager.shared.success()
                    let action = self.isEditMode ? "updated" : "saved"
                    log("✅ Approach \(action) successfully!")

                    // Only a new entry is a logged approach. An edit is a
                    // correction to one already counted — capturing it here
                    // too would inflate the app's headline activation metric
                    // every time someone fixed a typo.
                    //
                    // Read before the two asyncAfter blocks below reset the
                    // form (+2.5s); `total_approaches` was written by
                    // updateUserStats() during saveToSupabase(), so it is
                    // already the post-save count.
                    if !self.isEditMode {
                        let total = UserDefaults.standard.integer(forKey: "total_approaches")
                        Analytics.capture(Analytics.Event.approachLogged, [
                            "approach_level": self.selectedLevel,
                            "level_name": self.levels[self.selectedLevel - 1].title,
                            "anxiety_level": Int(self.anxietyLevel),
                            "has_notes": !self.notes.isEmpty,
                            "notes_length": self.notes.count,
                            "total_approaches": total,
                            "is_first_approach": total == 1,
                        ])

                        // XP for the log. Only for a new entry, for the same
                        // reason the event above is: an edit is a correction to
                        // one already counted.
                        //
                        // `source_id` is the row's own id, so the ledger is
                        // auditable against `approach_logs` and an outbox retry
                        // cannot pay twice. Flat 50, but the server refuses it
                        // past 250 in a local day — the cap lives in `xp_rules`,
                        // not here.
                        if let newApproachId {
                            Task {
                                await XPStore.shared.award(.approach, sourceId: newApproachId)
                            }
                        }
                    }

                    // Auto-hide success after 2 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.showSuccess = false
                    }
                    
                    // Reset form
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        self.resetForm()
                        self.editingApproachId = nil
                    }
                }
                
            } catch {
                await MainActor.run {
                    self.isSaving = false
                    HapticManager.shared.error()
                    let action = self.isEditMode ? "update" : "save"
                    self.errorMessage = "Failed to \(action). Please try again."
                    log("❌ Error \(action)ing approach: \(error.localizedDescription)")

                    // The user only ever sees "Failed to save. Please try
                    // again." A Supabase outage, an expired session and a
                    // malformed row are indistinguishable from each other —
                    // and from a user who simply never logged anything.
                    Analytics.capture(Analytics.Event.approachLogFailed, [
                        "is_edit": self.isEditMode,
                        "approach_level": self.selectedLevel,
                        "error_message": error.localizedDescription,
                    ])
                    Analytics.captureError(error, context: "approach_save", [
                        "is_edit": self.isEditMode,
                    ])
                }
            }
        }
    }
    
    // MARK: - Update to Supabase
    private func updateInSupabase() async throws {
        guard let userId = getUserId(),
              let approachId = editingApproachId else {
            throw NSError(domain: "LogApproach", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid update data"])
        }
        
        struct ApproachUpdateData: Codable {
            let title: String
            let approachLevel: Int
            let anxietyLevel: Int
            let notes: String?
            let updatedAt: String
            
            enum CodingKeys: String, CodingKey {
                case title
                case approachLevel = "approach_level"
                case anxietyLevel = "anxiety_level"
                case notes
                case updatedAt = "updated_at"
            }
        }
        
        let updateData = ApproachUpdateData(
            title: title,
            approachLevel: selectedLevel,
            anxietyLevel: Int(anxietyLevel),
            notes: notes.isEmpty ? nil : notes,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        
        log("📤 Updating in Supabase:")
        log("   - ID: \(approachId.uuidString)")
        log("   - User ID: \(userId)")
        log("   - Title: \(updateData.title)")
        log("   - Level: \(updateData.approachLevel)")
        log("   - Confidence: \(updateData.anxietyLevel)")
        
        try await client
            .from("approach_logs")
            .update(updateData)
            .eq("id", value: approachId.uuidString)
            .eq("user_id", value: userId)
            .execute()
        
        log("✅ Successfully updated in database")
        
        // Refresh the shared approach service to update UI
        await ApproachService.shared.fetchApproaches()
    }

    // MARK: - Save to Supabase
    /// Returns the id of the row it created, so the caller can hang the XP
    /// award off it. The id is generated here rather than read back because the
    /// insert does not `select()` — `approach_logs.id` has a
    /// `gen_random_uuid()` default but accepts an explicit value, so supplying
    /// one costs nothing and avoids a second round trip.
    @discardableResult
    private func saveToSupabase() async throws -> UUID {
        guard let userId = getUserId() else {
            throw NSError(domain: "LogApproach", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])
        }

        struct ApproachLog: Codable {
            let id: String
            let userId: String
            let title: String
            let approachLevel: Int
            let anxietyLevel: Int
            let notes: String?
            let loggedAt: String

            enum CodingKeys: String, CodingKey {
                case id
                case userId = "user_id"
                case title
                case approachLevel = "approach_level"
                case anxietyLevel = "anxiety_level"
                case notes
                case loggedAt = "logged_at"
            }
        }

        let newId = UUID()
        let approachLog = ApproachLog(
            id: newId.uuidString,
            userId: userId,
            title: title,
            approachLevel: selectedLevel,
            anxietyLevel: Int(anxietyLevel),
            notes: notes.isEmpty ? nil : notes,
            loggedAt: ISO8601DateFormatter().string(from: Date())
        )

        log("📤 Sending to Supabase:")
        log("   - User ID: \(userId)")
        log("   - Title: \(approachLog.title)")
        log("   - Level: \(approachLog.approachLevel)")
        log("   - Confidence: \(approachLog.anxietyLevel)")

        try await client
            .from("approach_logs")
            .insert(approachLog)
            .execute()
        
        log("✅ Successfully inserted into database")

        // Refresh the shared approach service to update UI
        await ApproachService.shared.fetchApproaches()

        // Update streak and stats
        updateUserStats()

        return newId
    }
    
    private func updateUserStats() {
        // Only update stats for new entries, not edits
        if !isEditMode {
            // Update practice date and streak
            UserDefaults.standard.set(Date(), forKey: "last_practice_date")
            
            // Increment approach count
            let currentCount = UserDefaults.standard.integer(forKey: "total_approaches")
            UserDefaults.standard.set(currentCount + 1, forKey: "total_approaches")
            
            log("📊 Stats updated:")
            log("   - Total approaches: \(currentCount + 1)")
        }
    }
    
    private func resetForm() {
        title = ""
        selectedLevel = 2
        anxietyLevel = 5.0
        notes = ""
        log("🔄 Form reset to defaults")
    }
    
    private func getUserId() -> String? {
        // Route through SupabaseManager so there is a single source of truth
        // for auth state (Supabase SDK session). Previously this read from a
        // UserDefaults cache that could lag behind the SDK after session
        // restoration and cause "notAuthenticated" failures.
        return SupabaseManager.shared.currentUserId
    }
}

// MARK: - Approach Level Model
struct ApproachLevel: Identifiable {
    let id = UUID()
    let number: Int
    let title: String
}
