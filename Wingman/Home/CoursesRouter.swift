// CoursesRouter.swift
import SwiftUI
import Combine

final class CoursesRouter: ObservableObject {
    // inputs for deep link
    @Published var initialSelectedCategoryId: String? = nil
    @Published var initialScrollToCourseId: String? = nil
    // bump to notify CoursesView to re-apply
    @Published var trigger: Int = 0
    
    func open(categoryId: String, courseId: String? = nil) {
        initialSelectedCategoryId = categoryId
        initialScrollToCourseId = courseId
        trigger &+= 1
    }
}
