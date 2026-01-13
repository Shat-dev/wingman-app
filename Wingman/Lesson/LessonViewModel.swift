//
//  LessonViewModel.swift
//  Wingman
//

import Foundation
import Combine

class LessonViewModel: ObservableObject {
    @Published var currentContentIndex: Int = 0
    @Published var visibleContent: [LessonContent] = []
    @Published var showLessonComplete: Bool = false
    @Published var progress: Double = 0.0
    @Published var nextLessonInfo: NextLessonInfo?
    
    private let lesson: Lesson
    private let dataService = LessonDataService.shared
    private var scrollToBottom: (() -> Void)?
    
    var totalContentCount: Int {
        lesson.content.count
    }
    
    var canGoForward: Bool {
        currentContentIndex < totalContentCount
    }
    
    var canGoBack: Bool {
        currentContentIndex > 0
    }
    
    init(lesson: Lesson) {
        self.lesson = lesson
        updateProgress()
        loadNextLessonInfo()
    }
    
    // MARK: - Navigation
    func goForward() {
        guard canGoForward else {
            // Lesson complete
            showLessonComplete = true
            return
        }
        
        // Add next content line
        let nextContent = lesson.content[currentContentIndex]
        visibleContent.append(nextContent)
        currentContentIndex += 1
        updateProgress()
        
        // Trigger scroll after content is added
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.scrollToBottom?()
        }
    }
    
    func goBack() {
        guard canGoBack else { return }
        
        // Remove last content line
        if !visibleContent.isEmpty {
            visibleContent.removeLast()
            currentContentIndex -= 1
            updateProgress()
        }
    }
    
    func setScrollHandler(_ handler: @escaping () -> Void) {
        self.scrollToBottom = handler
    }
    
    // MARK: - Progress
    private func updateProgress() {
        // Start at 1% minimum (not 0) so progress bar is visible from the start
        let calculatedProgress = Double(currentContentIndex) / Double(totalContentCount)
        progress = max(0.01, calculatedProgress)
    }
    
    // MARK: - Next Lesson
    private func loadNextLessonInfo() {
        nextLessonInfo = dataService.getNextLesson(
            currentLessonId: lesson.id,
            courseId: lesson.courseId
        )
    }
    
    // MARK: - Complete Lesson
    func completeLesson() {
        // Mark lesson as complete (you can persist this)
        print("✅ Lesson \(lesson.id) completed")
    }
}
