//
//  LessonQuizFlowView.swift
//  Wingman
//

import SwiftUI

/// The end-of-lesson knowledge check: the questions, then the existing
/// `LessonCompleteView`.
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

    /// Paragraphs already read, so the progress bar can continue from where the
    /// reading left off instead of restarting. See `totalStepCount`.
    let readingStepCount: Int

    let nextLessonInfo: NextLessonInfo?

    /// Fires the instant the completion screen is reached, carrying
    /// `(correctCount, questionCount)`.
    ///
    /// **This is where XP is awarded, not `onComplete`.** The award used to hang
    /// off the Continue button, which meant the lesson was paid for as the user
    /// left — so the reward screen could never display its own award and instead
    /// showed whatever was left over from the previous completion. A scenario
    /// finished 29 seconds earlier would decorate the lesson screen with its 50.
    ///
    /// Firing here also gives the round trip the whole intro animation as
    /// runway, which is the difference between the XP landing before the user
    /// taps through and missing the moment entirely.
    ///
    /// **Both are 0 when no quiz ran.** A lesson with no authored questions
    /// enters `.complete` directly (see `init`), and the server reads
    /// `questionCount == 0` as "no perfect bonus applies". Passing the
    /// denominator is what keeps "no quiz" distinguishable from "answered
    /// everything wrong" — without it the two would pay the same.
    let onReachedCompletion: (Int, Int) -> Void

    /// Runs when the user taps Continue — the point at which the lesson is
    /// actually marked complete and `lesson_completed` fires.
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss

    /// One-shot latch for `onReachedCompletion`.
    @State private var hasReportedCompletion = false

    @State private var step: Step
    @State private var engine: QuizEngine
    @State private var startedAt: Date?

    private enum Step {
        case questions
        case complete
    }

    init(
        lesson: Lesson,
        questions: [QuizQuestion],
        readingStepCount: Int,
        nextLessonInfo: NextLessonInfo?,
        onReachedCompletion: @escaping (Int, Int) -> Void,
        onComplete: @escaping () -> Void
    ) {
        self.onReachedCompletion = onReachedCompletion
        self.lesson = lesson
        self.questions = questions
        self.readingStepCount = readingStepCount
        self.nextLessonInfo = nextLessonInfo
        self.onComplete = onComplete
        _engine = State(initialValue: QuizEngine(questions: questions))
        _step = State(initialValue: questions.isEmpty ? .complete : .questions)
    }

    /// Shared analytics identity, matching `LessonView.lessonProperties`.
    private var lessonProperties: [String: Any] {
        [
            "lesson_id": lesson.id,
            "lesson_name": lesson.title,
            "category": lesson.courseTitle
        ]
    }

    /// Paragraphs + questions, matching `LessonView.totalStepCount` exactly.
    /// Both views must denominate by the same total or the bar jumps when the
    /// cover appears.
    private var totalStepCount: Int {
        readingStepCount + questions.count
    }

    /// Picks up precisely where the reading left off: the final paragraph put
    /// the bar at `readingStepCount / totalStepCount`, and question 1 advances
    /// it by one step.
    private var overallProgress: Double {
        guard totalStepCount > 0 else { return 1.0 }
        switch step {
        case .questions:
            return Double(readingStepCount + engine.currentQuestionIndex + 1) / Double(totalStepCount)
        case .complete:
            return 1.0
        }
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            switch step {
            case .questions:
                questionsView
            case .complete:
                // `LessonCompleteView.onContinue` stays `() -> Void` — it
                // renders a title and a button and has no business knowing a
                // score.
                //
                // `questions.count`, not `engine.answeredCount`: the perfect
                // bonus must mean "got the whole set right". The two are equal
                // at this point anyway — `.finished` is only reachable by
                // advancing past the last question, and `advance()` is blocked
                // until the answer is checked.
                LessonCompleteView(
                    nextLessonInfo: nextLessonInfo,
                    onContinue: onComplete
                )
                .onAppear {
                    // Guarded: `.complete` can re-render, and awarding twice
                    // would be a wasted round trip (the ledger would reject the
                    // second, but the screen would flicker through a reveal).
                    guard !hasReportedCompletion else { return }
                    hasReportedCompletion = true
                    onReachedCompletion(engine.correctCount, questions.count)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: engine.hasCheckedAnswer)
        .animation(.easeInOut(duration: 0.2), value: engine.selectedOptionIndex)
        .animation(.easeInOut(duration: 0.2), value: engine.selectedOptionIndices)
        .onAppear {
            // The check begins the moment the cover opens — there is no intro
            // step to gate it behind. Guarded so a re-appear can't emit a second
            // start for the same sitting.
            guard startedAt == nil, !questions.isEmpty else { return }
            startedAt = Date()

            var properties = lessonProperties
            properties["question_count"] = questions.count
            Analytics.capture(Analytics.Event.lessonQuizStarted, properties)
        }
    }

    // MARK: - Questions

    /// Top bar geometry is identical to `LessonView`'s reading bar — same 44pt
    /// chevron, same paddings — so the chrome doesn't shift when the cover
    /// appears over the lesson.
    private var questionsView: some View {
        VStack(spacing: 0) {
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
            .padding(.bottom, 10)

            QuizQuestionView(
                state: engine.questionState,
                onSelectOption: { index in
                    engine.selectOption(at: index)
                },
                onCheckAnswer: {
                    HapticManager.shared.tapStrong()
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

        case .questions:
            // Backing out of the check leaves the lesson incomplete — the user
            // returns to the last screen they were reading and can retry.
            var properties = lessonProperties
            properties["questions_answered"] = engine.answeredCount
            Analytics.capture(Analytics.Event.lessonQuizAbandoned, properties)
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
