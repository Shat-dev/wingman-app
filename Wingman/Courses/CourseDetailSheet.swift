//
//  CourseDetailSheet.swift
//  Wingman
//

import SwiftUI
import PostHog

struct CourseDetailSheet: View {
    let course: Course
    /// Drives the "coming soon" / "awaiting previous course" banner and
    /// gates lesson interaction when the course is locked. Defaults to
    /// `.unlocked` so preview and any legacy callers still work.
    var lockReason: CourseLockReason = .unlocked

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    @State private var lessons: [Lesson] = []

    // State-driven navigation for lesson entry (replaces the NavigationLink
    // previously inside LessonCard). This is required to subscription-gate
    // the tap BEFORE the push happens — NavigationLink doesn't offer an
    // onTap hook, and gating inside LessonView.onAppear would briefly flash
    // the lesson content before the paywall appears and leave a polluted
    // navigation back-stack.
    @State private var lessonToPresent: Lesson?
    @State private var isPresentingLesson = false

    // Feature-gate paywall for unlocked-lesson taps (free users).
    // Progression-locked lessons are disabled at the Button level and never
    // reach the gate — matches the "reduce paywall spam" requirement.
    @State private var showPaywall = false

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
                    .buttonStyle(ScalePressStyle())
                    
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
                                LessonCard(lesson: lesson) {
                                    // Progression-locked: Button is disabled,
                                    // this closure won't fire. Explicit guard
                                    // kept as belt-and-suspenders against
                                    // future refactors.
                                    guard !lesson.isLocked else { return }

                                    if authManager.hasActiveSubscription {
                                        lessonToPresent = lesson
                                        isPresentingLesson = true
                                    } else {
                                        showPaywall = true
                                    }
                                }
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
        .navigationDestination(isPresented: $isPresentingLesson) {
            if let lesson = lessonToPresent {
                LessonView(lesson: lesson, allLessons: lessons)
                    .onDisappear {
                        // Refresh lesson progress (completion state, next-lesson
                        // unlocks) when returning from the lesson. Matches the
                        // prior NavigationLink's onDisappear behavior exactly.
                        loadLessons()
                    }
            }
        }
        .subscriptionGate(isPresented: $showPaywall)
        .onAppear {
            // Only record last-accessed for unlocked courses so the Home
            // "Continue" card never points at a locked preview.
            if !isLocked {
                HomeViewModel.saveLastAccessedCourse(courseId: course.id)
            }
            loadLessons()
        }
        .postHogScreenView("Course Detail")
    }

    /// Banner copy. Nil when the course is unlocked (no banner rendered).
    private var lockBannerText: String? {
        switch lockReason {
        case .unlocked:
            return nil
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
            log("📋 Course Summary: \(firstLesson.courseSummary ?? "No summary")")
        }
    }
}

// MARK: - Lesson Card
//
// The card no longer manages its own navigation. It delegates the tap to
// a closure provided by the parent (CourseDetailSheet), which decides
// whether to present the lesson, show a paywall, or no-op for
// progression-locked lessons. This separation is what lets the parent
// subscription-gate the tap BEFORE any navigation animation.
struct LessonCard: View {
    let lesson: Lesson
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
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
        .buttonStyle(ScalePressStyle())
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
