//
//  LessonQuizFlowView.swift
//  Wingman
//

import SwiftUI

/// The end-of-lesson knowledge check: a short intro, the questions, then the
/// existing `LessonCompleteView`.
///
/// Presented from `LessonView` as a `.fullScreenCover`, replacing the cover
/// that previously showed `LessonCompleteView` directly. A cover rather than a
/// navigation push because `LessonView` sits inside two different
/// `NavigationStack`s depending on entry point (Courses → Course → Lesson, or
/// Home Continue → Course → Lesson); a cover behaves identically in both, has
/// no swipe-to-dismiss to escape mid-answer, and leaves `LessonCompleteView`'s
/// `onContinue` contract untouched.
///
/// **A lesson with no questions goes straight to `.complete`.** Un-authored
/// content and a cold cache on a fresh offline install both land there, and the
/// lesson finishes exactly as it did before this feature existed. That
/// fallthrough is what makes per-course content rollout possible.
struct LessonQuizFlowView: View {

    let lesson: Lesson
    let questions: [QuizQuestion]
    let nextLessonInfo: NextLessonInfo?

    /// Runs when the user taps Continue on the completion screen — the point at
    /// which the lesson is actually marked complete.
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var step: Step
    @State private var engine: QuizEngine
    @State private var startedAt: Date?

    private enum Step {
        case intro
        case questions
        case complete
    }

    init(
        lesson: Lesson,
        questions: [QuizQuestion],
        nextLessonInfo: NextLessonInfo?,
        onComplete: @escaping () -> Void
    ) {
        self.lesson = lesson
        self.questions = questions
        self.nextLessonInfo = nextLessonInfo
        self.onComplete = onComplete
        _engine = State(initialValue: QuizEngine(questions: questions))
        _step = State(initialValue: questions.isEmpty ? .complete : .intro)
    }

    /// Shared analytics identity, matching `LessonView.lessonProperties`.
    private var lessonProperties: [String: Any] {
        [
            "lesson_id": lesson.id,
            "lesson_name": lesson.title,
            "category": lesson.courseTitle
        ]
    }

    /// The lesson's progress bar continues into the quiz rather than restarting,
    /// so it stays obvious this is still the same lesson. Reading fills to 80%;
    /// the check fills the rest.
    private var overallProgress: Double {
        switch step {
        case .intro:    return 0.8
        case .questions: return 0.8 + 0.2 * engine.progress
        case .complete:  return 1.0
        }
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            switch step {
            case .intro:
                introView
            case .questions:
                questionsView
            case .complete:
                LessonCompleteView(
                    nextLessonInfo: nextLessonInfo,
                    onContinue: onComplete
                )
            }
        }
        .animation(.easeInOut(duration: 0.3), value: engine.hasCheckedAnswer)
        .animation(.easeInOut(duration: 0.2), value: engine.selectedOptionIndex)
        .animation(.easeInOut(duration: 0.2), value: engine.selectedOptionIndices)
    }

    // MARK: - Top Bar

    /// Same geometry as `LessonView`'s reading bar so the transition into the
    /// check doesn't shift the chrome.
    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                handleBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22))
                    .foregroundColor(.wingmanBlack)
                    .frame(width: 44, height: 44, alignment: .center)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ScalePressStyle())

            QuizProgressBar(progress: overallProgress)
        }
        .padding(.top, 8)
        .padding(.leading, 5)
        .padding(.trailing, 59)
    }

    /// Course above lesson, so it reads as "still inside this lesson".
    private var lessonHeader: some View {
        VStack(spacing: 2) {
            Text(lesson.courseTitle)
                .font(.manropeMedium(size: 12))
                .foregroundColor(Color(hex: "1A1A1A"))
                .opacity(0.5)

            Text(lesson.title)
                .font(.manropeSemiBold(size: 14))
                .foregroundColor(.wingmanBlack)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    // MARK: - Intro
    //
    // One tap, but it earns its place: the reading UI advances on a tap
    // *anywhere*, the quiz needs a tap on a specific option. Without a beat
    // between them, the tap that ends the lesson can land on an answer.

    private var introView: some View {
        VStack(spacing: 0) {
            topBar
            lessonHeader
                .padding(.top, 10)

            Spacer()

            VStack(spacing: 12) {
                Text("Knowledge Check")
                    .font(.manropeSemiBold(size: 28))
                    .foregroundColor(.wingmanBlack)
                    .kerning(-0.3)

                Text(questions.count == 1
                     ? "Answer 1 quick question to complete this lesson."
                     : "Answer \(questions.count) quick questions to complete this lesson.")
                    .font(.manropeMedium(size: 16))
                    .foregroundColor(.wingmanBlack.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()

            Button(action: {
                HapticManager.shared.mediumImpact()
                startQuestions()
            }) {
                Text("Start")
                    .font(.manropeSemiBold(size: 16))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.wingmanBlack)
                    .cornerRadius(5)
            }
            .buttonStyle(ScalePressStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Questions

    private var questionsView: some View {
        VStack(spacing: 0) {
            topBar
            lessonHeader
                .padding(.top, 10)
                .padding(.bottom, 4)

            QuizQuestionView(
                state: engine.questionState,
                onSelectOption: { index in
                    engine.selectOption(at: index)
                },
                onCheckAnswer: {
                    HapticManager.shared.mediumImpact()
                    guard let answer = engine.checkAnswer() else { return }
                    record(answer)
                },
                onNext: {
                    handleNext()
                }
            )
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Flow

    private func startQuestions() {
        startedAt = Date()
        step = .questions

        Analytics.capture(Analytics.Event.lessonQuizStarted, lessonProperties.merging([
            "question_count": questions.count
        ]) { _, new in new })
    }

    private func handleNext() {
        switch engine.advance() {
        case .blocked, .moved:
            break

        case .finished:
            HapticManager.shared.success()

            var properties = lessonProperties
            properties["question_count"] = questions.count
            properties["correct_count"] = engine.correctCount
            if let startedAt {
                properties["duration_seconds"] = Analytics.elapsedSeconds(since: startedAt)
            }
            Analytics.capture(Analytics.Event.lessonQuizCompleted, properties)

            step = .complete
        }
    }

    private func handleBack() {
        switch step {
        case .questions where engine.currentQuestionIndex > 0:
            engine.goBack()

        case .intro, .questions:
            // Backing out of the check leaves the lesson incomplete — the user
            // returns to the last screen they were reading and can retry.
            if step == .questions {
                var properties = lessonProperties
                properties["questions_answered"] = engine.answeredCount
                Analytics.capture(Analytics.Event.lessonQuizAbandoned, properties)
            }
            dismiss()

        case .complete:
            break
        }
    }

    /// Fire-and-forget. A failed write costs the review loop one data point; it
    /// must never block finishing a lesson, and it deliberately does not touch
    /// `user_question_completions`.
    private func record(_ answer: QuizAnswer) {
        let questionId = answer.question.id
        let lessonId = lesson.id
        let isCorrect = answer.isCorrect

        Task {
            do {
                try await LessonQuestionService().recordAnswer(
                    questionId: questionId,
                    lessonId: lessonId,
                    isCorrect: isCorrect
                )
            } catch {
                log("⚠️ Lesson quiz answer not recorded: \(error.localizedDescription)")
            }
        }
    }
}
