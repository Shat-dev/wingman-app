//
//  LessonView.swift
//  Wingman
//

import SwiftUI

struct LessonView: View {
    @StateObject private var viewModel: LessonViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var scrollViewID = UUID()
    
    init(lesson: Lesson) {
        _viewModel = StateObject(wrappedValue: LessonViewModel(lesson: lesson))
    }
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Navigation Bar with Progress
                HStack(spacing: 12) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 44, height: 44, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    // Progress Bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 10)
                            
                            Capsule()
                                .fill(Color.black)
                                .frame(width: geometry.size.width * viewModel.progress, height: 10)
                                .animation(.easeInOut(duration: 0.25), value: viewModel.progress)
                        }
                    }
                    .frame(height: 10)
                }
                .padding(.top, 8)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                
                // MARK: - Content Area with Interactive Zones
                ZStack {
                    // Content ScrollView
                    ScrollViewReader { proxy in
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 16) {
                                Spacer().frame(height: 20)
                                
                                ForEach(viewModel.visibleContent) { content in
                                    Text(content.text)
                                        .font(.manropeRegular(size: 16))
                                        .foregroundColor(.black)
                                        .lineSpacing(6)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .id(content.id)
                                }
                                
                                // Bottom spacer for scroll
                                Color.clear
                                    .frame(height: 1)
                                    .id("bottom")
                            }
                            .padding(.horizontal, 20)
                        }
                        .onAppear {
                            viewModel.setScrollHandler {
                                withAnimation {
                                    proxy.scrollTo("bottom", anchor: .bottom)
                                }
                            }
                        }
                    }
                    
                    // MARK: - Interactive Tap Zones
                    HStack(spacing: 0) {
                        // Left side - Go Back
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.goBack()
                                }
                            }
                        
                        // Center line (visual guide) - only show when no content
                        if viewModel.visibleContent.isEmpty {
                            Rectangle()
                                .fill(Color.gray.opacity(0.1))
                                .frame(width: 1)
                        }
                        
                        // Right side - Go Forward
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.goForward()
                                }
                            }
                    }
                    
                    // MARK: - Back/Forward Labels (only when no content) - VERTICALLY CENTERED
                    if viewModel.visibleContent.isEmpty {
                        VStack {
                            Spacer()
                            
                            HStack {
                                Text("Back")
                                    .font(.manropeRegular(size: 14))
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text("Forward")
                                    .font(.manropeRegular(size: 14))
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                            .padding(.horizontal, 40)
                            
                            Spacer()
                        }
                    }
                }
                
                // Bottom subtitle
                Text(viewModel.nextLessonInfo?.subtitle ?? "")
                    .font(.manropeRegular(size: 13))
                    .foregroundColor(.gray)
                    .padding(.vertical, 20)
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $viewModel.showLessonComplete) {
            LessonCompleteView(
                nextLessonInfo: viewModel.nextLessonInfo,
                onContinue: {
                    viewModel.completeLesson()
                    dismiss()
                }
            )
        }
    }
}

#Preview {
    LessonView(lesson: Lesson(
        id: "lesson_1",
        courseId: "course_1",
        lessonNumber: 1,
        title: "Your are not your thoughts",
        subtitle: "Courage Comes first, Confidence follows",
        duration: 3,
        content: [
            LessonContent(text: "When you know you smell fresh, look clean, and feel put together, you can stop worrying about how you come across.", order: 0),
            LessonContent(text: "Good hygiene is about removing the invisible barriers that push people away.", order: 1)
        ],
        isCompleted: false,
        isLocked: false
    ))
}
