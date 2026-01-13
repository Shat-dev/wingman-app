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
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Course Title and Description
                        VStack(alignment: .leading, spacing: 12) {
                            Text(course.title)
                                .font(.manropeSemiBold(size: 24))
                                .foregroundColor(.black)
                            
                            if let description = course.description {
                                Text(description)
                                    .font(.manropeRegular(size: 15))
                                    .foregroundColor(.gray)
                                    .lineSpacing(4)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        
                        // Lessons List
                        VStack(spacing: 12) {
                            ForEach(lessons) { lesson in
                                LessonCard(
                                    lessonNumber: lesson.lessonNumber,
                                    title: lesson.title,
                                    duration: lesson.duration,
                                    description: lesson.content.first?.text ?? "",
                                    isCompleted: lesson.isCompleted,
                                    isLocked: lesson.isLocked,
                                    lesson: lesson
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
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                    }
                }
            }
            .onAppear {
                loadLessons()
            }
        }
    }
    
    private func loadLessons() {
        lessons = LessonDataService.shared.loadLessonsForCourse(courseId: course.id)
    }
}

// MARK: - Lesson Card
struct LessonCard: View {
    let lessonNumber: Int
    let title: String
    let duration: Int
    let description: String
    let isCompleted: Bool
    let isLocked: Bool
    let lesson: Lesson
    @State private var showLesson = false
    
    var body: some View {
        Button(action: {
            if !isLocked {
                print("🎓 Lesson \(lessonNumber) tapped")
                showLesson = true
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                
                // Title and Duration
                HStack(alignment: .top) {
                    Text(title)
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(isLocked ? .gray.opacity(0.4) : .black)
                        .multilineTextAlignment(.leading)
                    
                    Spacer()
                    
                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.black)
                    }
                }
                
                // Duration
                Text("\(duration) min")
                    .font(.manropeRegular(size: 13))
                    .foregroundColor(isLocked ? .gray.opacity(0.4) : .gray)
                
                // Description
                Text(description)
                    .font(.manropeRegular(size: 14))
                    .foregroundColor(isLocked ? .gray.opacity(0.4) : .gray)
                    .lineSpacing(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCompleted ? Color.black : Color.black.opacity(0.1), lineWidth: isCompleted ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isLocked)
        .fullScreenCover(isPresented: $showLesson) {
            LessonView(lesson: lesson)
        }
    }
}

#Preview {
    CourseDetailSheet(course: Course(
        id: "1",
        categoryId: "cat_1",
        title: "Fear & Exposure",
        description: "Navigate the energy of a bustling nightclub and master the art of confident social interaction.",
        thumbnailName: "course_fear",
        lessonsCount: 5,
        duration: 15,
        isLocked: false,
        displayOrder: 1
    ))
}
