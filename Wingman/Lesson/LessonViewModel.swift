//
//  LessonViewModel.swift
//  Wingman
//

import Foundation
import Combine

class LessonViewModel: ObservableObject {
    @Published var currentScreenIndex: Int = 0
    @Published var currentContentIndex: Int = 0
    @Published var visibleContent: [LessonContent] = []
    @Published var showLessonComplete: Bool = false
    @Published var progress: Double = 0.0
    @Published var nextLessonInfo: NextLessonInfo?
    
    private let lesson: Lesson
    private let dataService = LessonDataService.shared
    private var scrollToBottom: (() -> Void)?
    
    // Screens sorted by order
    var sortedScreens: [LessonScreen] {
        lesson.screens.sorted { $0.order < $1.order }
    }
    
    // Current screen's content sorted by order
    var currentScreenContent: [LessonContent] {
        guard currentScreenIndex < sortedScreens.count else { return [] }
        return sortedScreens[currentScreenIndex].content.sorted { $0.order < $1.order }
    }
    
    // Total content count across ALL screens (for progress calculation)
    var totalContentCount: Int {
        sortedScreens.reduce(0) { $0 + $1.content.count }
    }
    
    // Current progress position
    var currentProgressPosition: Int {
        var position = 0
        for i in 0..<currentScreenIndex {
            position += sortedScreens[i].content.count
        }
        position += currentContentIndex
        return position
    }
    
    var canGoForward: Bool {
        // Can go forward if there's more content on current screen OR more screens
        if currentContentIndex < currentScreenContent.count {
            return true
        }
        return currentScreenIndex < sortedScreens.count - 1
    }
    
    var canGoBack: Bool {
        currentContentIndex > 0 || currentScreenIndex > 0
    }
    
    init(lesson: Lesson) {
        self.lesson = lesson
        updateProgress()
        loadNextLessonInfo()
    }
    
    // MARK: - Navigation
    func goForward() {
        if currentContentIndex < currentScreenContent.count {
            // Add next content line from current screen
            let nextContent = currentScreenContent[currentContentIndex]
            visibleContent.append(nextContent)
            currentContentIndex += 1
            updateProgress()
            
            // Trigger scroll after content is added
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.scrollToBottom?()
            }
        } else if currentScreenIndex < sortedScreens.count - 1 {
            // Move to next screen
            currentScreenIndex += 1
            currentContentIndex = 0
            visibleContent.removeAll()
            
            // Show first content of new screen
            if !currentScreenContent.isEmpty {
                visibleContent.append(currentScreenContent[0])
                currentContentIndex = 1
            }
            updateProgress()
        } else {
            // Lesson complete
            showLessonComplete = true
        }
    }
    
    func goBack() {
        if currentContentIndex > 1 {
            // Remove last content line from current screen
            if !visibleContent.isEmpty {
                visibleContent.removeLast()
                currentContentIndex -= 1
                updateProgress()
            }
        } else if currentContentIndex == 1 && currentScreenIndex > 0 {
            // Go to previous screen, show all its content
            currentScreenIndex -= 1
            let prevScreenContent = currentScreenContent
            visibleContent = prevScreenContent
            currentContentIndex = prevScreenContent.count
            updateProgress()
        } else if currentContentIndex == 1 && currentScreenIndex == 0 {
            // At first screen, first content - remove it
            visibleContent.removeAll()
            currentContentIndex = 0
            updateProgress()
        }
    }
    
    func setScrollHandler(_ handler: @escaping () -> Void) {
        self.scrollToBottom = handler
    }
    
    // MARK: - Progress
    private func updateProgress() {
        guard totalContentCount > 0 else {
            progress = 0
            return
        }
        // Start at 1% minimum (not 0) so progress bar is visible from the start
        let calculatedProgress = Double(currentProgressPosition) / Double(totalContentCount)
        progress = max(0.01, calculatedProgress)
    }
    
    // MARK: - Next Lesson
    private func loadNextLessonInfo() {
        if let nextLesson = dataService.getNextLesson(after: lesson) {
            nextLessonInfo = NextLessonInfo(
                title: nextLesson.title,
                subtitle: nextLesson.courseTitle
            )
        } else {
            nextLessonInfo = nil
        }
    }
    
    // MARK: - Complete Lesson
    func completeLesson() {
        // Mark lesson as complete (you can persist this)
        log("✅ Lesson \(lesson.id) completed")
    }
}
