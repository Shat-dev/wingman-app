//
//  CourseDetailSheet.swift
//  Wingman
//

import SwiftUI

struct CourseDetailSheet: View {
    let course: Course
    @Environment(\.dismiss) private var dismiss
    @State private var lessons: [Lesson] = []
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    
                    // MARK: - Course Title and Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text(course.title)
                            .font(.manropeSemiBold(size: 20))
                            .foregroundColor(.black)
                            .kerning(-0.3)
                        
                        // Course Summary from lessons data (gray text)
                        if let firstLesson = lessons.first,
                           let courseSummary = firstLesson.courseSummary {
                            Text(courseSummary)
                                .font(.manropeMedium(size: 14))
                                .foregroundColor(Color(hex: "1A1A1A"))
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 4)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 24)
                    
                    // MARK: - Lessons List
                    VStack(spacing: 12) {
                        ForEach(lessons) { lesson in
                            LessonCard(
                                lesson: lesson,
                                allLessons: lessons,
                                onLessonComplete: {
                                    // Refresh lessons when returning
                                    loadLessons()
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer().frame(height: 100)
                }
                .padding(.top, 12)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true) // Hide the default back button to avoid duplication
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                }
            }
        }
        .onAppear {
            loadLessons()
        }
    }
    
    private func loadLessons() {
        // Clear cache to get fresh data
        LessonDataService.shared.clearCache()
        lessons = LessonDataService.shared.loadLessonsForCourse(courseId: course.id)
        
        // Debug: Print course summary
        if let firstLesson = lessons.first {
            print("📋 Course Summary: \(firstLesson.courseSummary ?? "No summary")")
        }
    }
}

// MARK: - Lesson Card
struct LessonCard: View {
    let lesson: Lesson
    let allLessons: [Lesson]
    var onLessonComplete: (() -> Void)?
    
    @State private var showLesson = false
    
    var body: some View {
        Button(action: {
            if !lesson.isLocked {
                print("🎯 Lesson \(lesson.lessonNumber) tapped: \(lesson.title)")
                showLesson = true
            }
        }) {
            VStack(alignment: .leading, spacing: 0) {
                
                // MARK: - Title Row
                HStack(alignment: .top, spacing: 12) {
                    Text(lesson.title)
                        .font(.manropeMedium(size: 18))
                        .foregroundColor(lesson.isLocked ? Color(hex: "CCCCCC") : .black)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                    
                    if lesson.isLocked {
                        Image("lock_icon")
                            .foregroundColor(.black)
                            .padding(.top, -10)
                    }
                }
                
                // MARK: - Duration
                Text("\(lesson.duration) min")
                    .font(.manropeMedium(size: 12))
                    .foregroundColor(lesson.isLocked ? Color(hex: "CCCCCC") : Color(hex: "888888"))
                    .padding(.top, 6)
                
                // MARK: - Summary
                Text(lesson.summary)
                    .font(.manropeMedium(size: 14))
                    .foregroundColor(lesson.isLocked ? Color(hex: "CCCCCC") : Color(hex: "666666"))
                    .lineSpacing(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 8)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(
                        lesson.isCompleted ? Color.black : Color.black.opacity(0.1),
                        lineWidth: lesson.isCompleted ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(lesson.isLocked)
        .fullScreenCover(isPresented: $showLesson, onDismiss: {
            // Refresh when returning from lesson
            onLessonComplete?()
        }) {
            LessonView(lesson: lesson, allLessons: allLessons)
        }
    }
}

#Preview {
    CourseDetailSheet(course: Course(
        id: "course_1",
        categoryId: "cat_1",
        title: "Beliefs & Reframes",
        description: "Transform limiting beliefs into empowering mindsets",
        courseSummary: "Learn to strengthen confidence by reframing limiting beliefs.",
        thumbnailName: "course_beliefs",
        lessonsCount: 5,
        duration: 12,
        isLocked: false,
        displayOrder: 1
    ))
}
