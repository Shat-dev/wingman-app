//
//  CoursesViewModel.swift
//  Wingman
//
//  Created by Adnan Khan on 07/01/2026.
//


//
//  CoursesViewModel.swift
//  Wingman
//

import Foundation
import Combine

final class CoursesViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var categories: [CourseCategory] = []
    @Published var selectedCategoryId: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    
    // MARK: - Services
    private let client = SupabaseManager.shared.client
    
    // MARK: - Computed Properties
    var selectedCategory: CourseCategory? {
        categories.first { $0.id == selectedCategoryId }
    }
    
    var availableCategories: [CourseCategory] {
        categories.sorted { $0.displayOrder < $1.displayOrder }
    }
    
    // MARK: - Init
    init() {
        print("📚 CoursesViewModel initialized")
        loadCourses()
    }
    
    // MARK: - Load Courses
    func loadCourses() {
        print("🔄 Loading courses...")

        // Synchronous load from static dummy data. No network, no delay.
        // TODO: Replace with Supabase fetch in future (see fetchCoursesFromSupabase below)
        self.categories = CourseCategory.dummyCategories

        // Select first category by default
        if let firstCategory = self.categories.first {
            self.selectedCategoryId = firstCategory.id
        }

        print("✅ Loaded \(self.categories.count) categories")
        print("✅ Total courses: \(self.categories.reduce(0) { $0 + $1.courses.count })")
    }
    
    // MARK: - Future: Fetch from Supabase
    func fetchCoursesFromSupabase() async throws {
        print("🌐 Fetching courses from Supabase...")
        
        // TODO: Implement when backend is ready
        // Example structure:
        /*
        struct CategoryResponse: Codable {
            let id: String
            let name: String
            let displayOrder: Int
        }
        
        struct CourseResponse: Codable {
            let id: String
            let categoryId: String
            let title: String
            let description: String?
            let thumbnailName: String
            let lessonsCount: Int
            let duration: Int?
            let isLocked: Bool
            let displayOrder: Int
        }
        
        // Fetch categories
        let categoriesResponse: [CategoryResponse] = try await client
            .from("course_categories")
            .select()
            .order("display_order", ascending: true)
            .execute()
            .value
        
        // Fetch courses
        let coursesResponse: [CourseResponse] = try await client
            .from("courses")
            .select()
            .order("display_order", ascending: true)
            .execute()
            .value
        
        // Group courses by category
        var categoriesDict: [String: [Course]] = [:]
        for course in coursesResponse {
            let courseModel = Course(
                id: course.id,
                categoryId: course.categoryId,
                title: course.title,
                description: course.description,
                thumbnailName: course.thumbnailName,
                lessonsCount: course.lessonsCount,
                duration: course.duration,
                isLocked: course.isLocked,
                displayOrder: course.displayOrder
            )
            categoriesDict[course.categoryId, default: []].append(courseModel)
        }
        
        // Create category models
        let categories = categoriesResponse.map { cat in
            CourseCategory(
                id: cat.id,
                name: cat.name,
                displayOrder: cat.displayOrder,
                courses: categoriesDict[cat.id] ?? []
            )
        }
        
        await MainActor.run {
            self.categories = categories
            if let firstCategory = categories.first {
                self.selectedCategoryId = firstCategory.id
            }
        }
        */
    }
    
    // MARK: - Actions
    func selectCategory(_ categoryId: String) {
        print("📂 Selected category: \(categoryId)")
        selectedCategoryId = categoryId
        
        if let category = categories.first(where: { $0.id == categoryId }) {
            print("   - Category name: \(category.name)")
            print("   - Courses count: \(category.courses.count)")
        }
    }
    
    func selectCourse(_ course: Course) {
        print("📖 Selected course: \(course.title)")
        print("   - ID: \(course.id)")
        print("   - Category: \(course.categoryId)")
        print("   - Lessons: \(course.lessonsCount)")
        print("   - Duration: \(course.duration ?? 0) minutes")
        print("   - Locked: \(course.isLocked)")
        
        if course.isLocked {
            print("🔒 Course is locked - Show upgrade prompt")
            // TODO: Show paywall or unlock prompt
        } else {
            print("✅ Course is unlocked - Navigate to course detail")
            // TODO: Navigate to course detail screen
        }
    }
    
    // MARK: - Helper
    func getCoursesForCategory(_ categoryId: String) -> [Course] {
        categories
            .first { $0.id == categoryId }?
            .courses
            .sorted { $0.displayOrder < $1.displayOrder }
            ?? []
    }
}
