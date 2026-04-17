//
//  CourseDetailSheet.swift
//  Wingman
//

import SwiftUI

struct CourseDetailSheet: View {
    let course: Course
    /// Drives the "coming soon" / "awaiting previous course" banner and
    /// gates lesson interaction when the course is locked. Defaults to
    /// `.unlocked` so preview and any legacy callers still work.
    var lockReason: CourseLockReason = .unlocked

    @Environment(\.dismiss) private var dismiss
    @State private var lessons: [Lesson] = []

    private var isLocked: Bool { lockReason.isLocked }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom back chevron (match other screens)
                HStack(spacing: 0) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22))
                            .foregroundColor(.wingmanBlack)
                            .frame(width: 44, height: 44, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                }
                .padding(.top, 5)
                .padding(.leading, 8)
                
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        
                        // MARK: - Course Title and Description
                        VStack(alignment: .leading, spacing: 8) {
                            Text(course.title)
                                .font(.manropeSemiBold(size: 20))
                                .foregroundColor(.wingmanBlack)
                                .kerning(-0.3)
                            
                            // Course Summary from lessons data (gray text)
                            if let firstLesson = lessons.first,
                               let courseSummary = firstLesson.courseSummary {
                                Text(courseSummary)
                                    .font(.manropeMedium(size: 14))
                                    .foregroundColor(Color(hex: "1A1A1A"))
                                    .lineSpacing(4)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding(.top, 2)
                                    .opacity(0.8)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 1)
                        .padding(.bottom, isLocked ? 16 : 30)

                        // MARK: - Lock Banner (preview mode)
                        if let bannerText = lockBannerText {
                            HStack(alignment: .top, spacing: 10) {
                                Image("lock_icon")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .foregroundColor(.wingmanBlack)
                                    .padding(.top, 2)

                                Text(bannerText)
                                    .font(.manropeMedium(size: 14))
                                    .foregroundColor(.wingmanBlack)
                                    .fixedSize(horizontal: false, vertical: true)

                                Spacer(minLength: 0)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.wingmanBlack.opacity(0.05))
                            .cornerRadius(5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.wingmanBlack.opacity(0.1), lineWidth: 1)
                            )
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }

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
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true) // ensure iOS back button is hidden
        .enableInteractivePopGesture()
        .onAppear {
            // Only record last-accessed for unlocked courses so the Home
            // "Continue" card never points at a locked preview.
            if !isLocked {
                HomeViewModel.saveLastAccessedCourse(courseId: course.id)
            }
            loadLessons()
        }
    }

    /// Banner copy. Nil when the course is unlocked (no banner rendered).
    private var lockBannerText: String? {
        switch lockReason {
        case .unlocked:
            return nil
        case .comingSoon:
            return "This course is locked."
        case .awaitingPrevious(let previousTitle):
            return "Complete all lessons in \(previousTitle) to unlock this course."
        }
    }

    private func loadLessons() {
        // Clear cache to get fresh data
        LessonDataService.shared.clearCache()
        var loaded = LessonDataService.shared.loadLessonsForCourse(courseId: course.id)

        // Preview mode: when the parent course is locked we force every
        // lesson to render as locked so the existing LessonCard .disabled
        // guard prevents any lesson from being opened. This mutation is
        // local-only (not persisted) — saveLessonProgress is never called
        // from this path.
        if isLocked {
            for i in loaded.indices {
                loaded[i].isLocked = true
            }
        }

        lessons = loaded

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
    
    var body: some View {
        // Use NavigationLink to get right-to-left push transition
        NavigationLink {
            LessonView(lesson: lesson, allLessons: allLessons)
                .onDisappear {
                    // Refresh when returning from lesson
                    onLessonComplete?()
                }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                
                // MARK: - Title Row
                HStack(alignment: .top, spacing: 12) {
                    Text(lesson.title)
                        .font(.manropeMedium(size: 18))
                        .foregroundColor(lesson.isLocked ? Color(hex: "CCCCCC") : .wingmanBlack)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    
                    Spacer()
                    
                    if lesson.isLocked {
                        Image("lock_icon")
                            .foregroundColor(.wingmanBlack)
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
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(
                        lesson.isCompleted ? Color.wingmanBlack : Color.wingmanBlack.opacity(0.1),
                        lineWidth: 1 // Always 1 px border
                    )
            )
            .shadow(color: Color.wingmanBlack.opacity(0.06), radius: 5, x: 0, y: 2) // elevation to match PracticeCardView
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(lesson.isLocked)
    }
}

#Preview {
    NavigationStack {
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
}
