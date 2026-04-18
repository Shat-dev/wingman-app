//
//  ApproachService.swift
//  Wingman
//

import Foundation
import Supabase
import Combine

// MARK: - Approach Log Database Model
struct ApproachLogResponse: Codable {
    let id: UUID
    let userId: String
    let title: String
    let approachLevel: Int
    let anxietyLevel: Int
    let notes: String?
    let loggedAt: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title
        case approachLevel = "approach_level"
        case anxietyLevel = "anxiety_level"
        case notes
        case loggedAt = "logged_at"
        case createdAt = "created_at"
    }
    
    // Convert to the local ApproachLog model
    func toApproachLog() -> ApproachLog {
        let dateFormatter = ISO8601DateFormatter()
        let date = dateFormatter.date(from: loggedAt) ?? Date()
        
        return ApproachLog(
            id: id,
            title: title,
            description: notes ?? "",
            level: approachLevel,
            anxietyLevel: anxietyLevel,
            date: date
        )
    }
}

// MARK: - Approach Service
@MainActor
class ApproachService: ObservableObject {
    static let shared = ApproachService()
    
    private let client = SupabaseManager.shared.client
    
    @Published var approaches: [ApproachLog] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var totalCount: Int = 0
    
    private init() {}
    
    // MARK: - Fetch Approaches
    func fetchApproaches() async {
        guard let userId = SupabaseManager.shared.currentUserId else {
            errorMessage = "User not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = ""
        
        do {
            log("🔄 Fetching approaches for user: \(userId)")
            
            let response: [ApproachLogResponse] = try await client
                .from("approach_logs")
                .select("*")
                .eq("user_id", value: userId)
                .order("logged_at", ascending: false)
                .execute()
                .value
            
            self.approaches = response.map { $0.toApproachLog() }
            self.totalCount = response.count
            
            log("✅ Fetched \(response.count) approaches")
            log("📊 Approaches breakdown:")
            for approach in self.approaches {
                log("   - \(approach.title) (Level \(approach.level), Anxiety: \(approach.anxietyLevel))")
            }
            
        } catch {
            log("❌ Error fetching approaches: \(error.localizedDescription)")
            self.errorMessage = "Failed to load approaches. Please try again."
        }
        
        self.isLoading = false
    }
    
    // MARK: - Get Approach Count
    func getApproachCount() async -> Int {
        guard let userId = SupabaseManager.shared.currentUserId else {
            return 0
        }
        
        do {
            let response = try await client
                .from("approach_logs")
                .select("id", count: .exact)
                .eq("user_id", value: userId)
                .execute()
            
            return response.count ?? 0
            
        } catch {
            log("❌ Error fetching approach count: \(error.localizedDescription)")
            return 0
        }
    }
    
    // MARK: - Delete Approach
    func deleteApproach(_ approach: ApproachLog) async -> Bool {
        guard let userId = SupabaseManager.shared.currentUserId else {
            errorMessage = "User not authenticated"
            return false
        }
        
        do {
            log("🗑️ Deleting approach: \(approach.title)")
            
            try await client
                .from("approach_logs")
                .delete()
                .eq("id", value: approach.id.uuidString)
                .eq("user_id", value: userId)
                .execute()
            
            // Remove from local array
            self.approaches.removeAll { $0.id == approach.id }
            self.totalCount = self.approaches.count
            
            log("✅ Approach deleted successfully")
            return true
            
        } catch {
            log("❌ Error deleting approach: \(error.localizedDescription)")
            self.errorMessage = "Failed to delete approach. Please try again."
            return false
        }
    }
    
    // MARK: - Search Approaches
    func searchApproaches(_ searchText: String) -> [ApproachLog] {
        if searchText.isEmpty {
            return approaches
        }
        
        return approaches.filter { approach in
            approach.title.localizedCaseInsensitiveContains(searchText) ||
            approach.description.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - Get Approaches Breakdown
    func getApproachesBreakdown() -> [(String, Int, Double)] {
        let levelCounts = Dictionary(grouping: approaches, by: { $0.level })
            .mapValues { $0.count }
        
        let maxCount = levelCounts.values.max() ?? 1
        
        let levelNames = [
            1: "Level 1: Social warm-up",
            2: "Level 2: Extended conversation", 
            3: "Level 3: Indirect approach",
            4: "Level 4: Direct approach"
        ]
        
        return (1...4).map { level in
            let count = levelCounts[level] ?? 0
            let progress = Double(count) / Double(maxCount)
            return (levelNames[level] ?? "Level \(level)", count, progress)
        }
    }
    
    // MARK: - Update User Stats
    func updateLocalStats() {
        // Update local UserDefaults with fresh data from Supabase
        UserDefaults.standard.set(totalCount, forKey: "total_approaches")
        
        if !approaches.isEmpty {
            UserDefaults.standard.set(Date(), forKey: "last_practice_date")
        }
        
        log("📊 Updated local stats: \(totalCount) total approaches")
    }
}