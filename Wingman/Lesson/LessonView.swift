//
//  LessonView.swift
//  Wingman
//

import SwiftUI

struct LessonView: View {
    let lesson: Lesson
    let allLessons: [Lesson]
    
    @Environment(\.dismiss) private var dismiss
    @State private var currentContentIndex: Int = -1 // -1 means intro screen
    @State private var showLessonComplete = false
    
    // Content items sorted by order
    private var sortedContent: [LessonContent] {
        lesson.content.sorted { $0.order < $1.order }
    }
    
    // Total segments for progress bar
    private var totalSegments: Int {
        sortedContent.count
    }
    
    // Currently visible content (accumulated)
    private var visibleContent: [LessonContent] {
        guard currentContentIndex >= 0 else { return [] }
        return Array(sortedContent.prefix(currentContentIndex + 1))
    }
    
    // Progress as a percentage (0.0 to 1.0)
    private var progress: Double {
        guard totalSegments > 0 else { return 0 }
        if currentContentIndex < 0 { return 0 }
        return Double(currentContentIndex + 1) / Double(totalSegments)
    }
    
    var body: some View {
        let _ = print("🎬 LessonView body rendering - Content items: \(sortedContent.count), Current index: \(currentContentIndex)")
        
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // MARK: - Top Bar
                HStack(alignment: .center, spacing: 12) {
                    // Back Button
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.black)
                    }
                    .frame(width: 44, height: 44)
                    
                    // Progress Bar (smooth)
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // Background
                            Capsule()
                                .fill(Color(hex: "E5E5E5"))
                                .frame(height: 4)
                            
                            // Foreground (progress)
                            Capsule()
                                .fill(Color.black)
                                .frame(width: geometry.size.width * progress, height: 4)
                                .animation(.easeInOut(duration: 0.2), value: progress)
                        }
                    }
                    .frame(height: 4)
                    
                    // Spacer for balance
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
                
                // MARK: - Content Area with Tap Gestures
                GeometryReader { geometry in
                    ZStack {
                        // Content
                        if currentContentIndex == -1 {
                            // Intro Screen
                            IntroScreenView()
                        } else {
                            // Content Screen
                            ContentScreenView(visibleContent: visibleContent)
                        }
                        
                        // Tap Areas (invisible overlay)
                        HStack(spacing: 0) {
                            // Left tap area - Go Back
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    print("🔵 LEFT SIDE TAPPED")
                                    goBack()
                                }
                            
                            // Right tap area - Go Forward
                            Rectangle()
                                .fill(Color.clear)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    print("🟢 RIGHT SIDE TAPPED")
                                    goForward()
                                }
                        }
                    }
                }
                
                // MARK: - Bottom Bar
                VStack(spacing: 0) {
                    Text(lesson.subtitle)
                        .font(.manropeRegular(size: 13))
                        .foregroundColor(Color(hex: "888888"))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showLessonComplete) {
            LessonCompleteView(
                nextLessonInfo: getNextLessonInfo(),
                onContinue: {
                    // Mark current lesson as completed
                    LessonDataService.shared.markLessonCompleted(
                        lessonId: lesson.id,
                        courseId: lesson.courseId
                    )
                    dismiss()
                }
            )
        }
    }
    
    // MARK: - Navigation Functions
    private func goBack() {
        print("⬅️ TAP DETECTED - goBack() called")
        print("   Current index: \(currentContentIndex)")
        if currentContentIndex > -1 {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentContentIndex -= 1
            }
            print("   ✅ Moved back to index: \(currentContentIndex)")
        } else {
            print("   ⚠️ Already at intro screen")
        }
    }
    
    private func goForward() {
        print("➡️ TAP DETECTED - goForward() called")
        print("   Current index: \(currentContentIndex)")
        print("   Total content items: \(sortedContent.count)")
        
        if currentContentIndex < sortedContent.count - 1 {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentContentIndex += 1
            }
            print("   ✅ Moved forward to index: \(currentContentIndex)")
            print("   📝 Now showing \(currentContentIndex + 1) of \(sortedContent.count) items")
            if currentContentIndex >= 0 && currentContentIndex < sortedContent.count {
                print("   📄 Content text: \(sortedContent[currentContentIndex].text.prefix(50))...")
            }
        } else {
            // Lesson complete
            print("   ✅ Lesson complete!")
            showLessonComplete = true
        }
    }
    
    private func getNextLessonInfo() -> NextLessonInfo? {
        if let nextLesson = LessonDataService.shared.getNextLesson(after: lesson) {
            return NextLessonInfo(
                title: nextLesson.title,
                subtitle: nextLesson.subtitle
            )
        }
        return nil
    }
}

// MARK: - Intro Screen View
struct IntroScreenView: View {
    var body: some View {
        HStack(spacing: 0) {
            // Back label
            VStack {
                Spacer()
                Text("Back")
                    .font(.manropeMedium(size: 20))
                    .foregroundColor(.black)
                    .opacity(0.5)
                    .padding(.leading, -55)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            
            // Forward label
            VStack {
                Spacer()
                Text("Forward")
                    .font(.manropeMedium(size: 20))
                    .foregroundColor(.black)
                    .opacity(0.5)
                    .padding(.leading, 20)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Content Screen View
struct ContentScreenView: View {
    let visibleContent: [LessonContent]
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(visibleContent.enumerated()), id: \.element.id) { index, content in
                        Text(content.text)
                            .font(.manropeRegular(size: 18))
                            .foregroundColor(.black)
                            .lineSpacing(8)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.bottom, index == visibleContent.count - 1 ? 0 : 20)
                            .id(content.id)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 60)
            }
            .onChange(of: visibleContent.count) { _ in
                if let lastContent = visibleContent.last {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(lastContent.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    LessonView(
        lesson: Lesson(
            id: "lesson_1_1",
            courseId: "course_1",
            courseSummary: "summery...",
            lessonNumber: 1,
            title: "You are not your thoughts",
            subtitle: "Courage Comes first, Confidence follows",
            duration: 3,
            summary: "Learn why negative thoughts feel convincing and how to stop letting them control you.",
            isCompleted: false,
            isLocked: false,
            content: [
                LessonContent(id: "content_1_1_1", text: "Your mind produces around 60,000 thoughts a day. Most are repetitive, some are negative, and nearly all vanish without impact. Yet we treat them like evidence of who we are.", order: 0),
                LessonContent(id: "content_1_1_2", text: "These thoughts aren't conscious choices; they are automatic reactions shaped by habit, fear, and memory. The problem isn't having them; it's believing each one reflects reality.", order: 1),
                LessonContent(id: "content_1_1_3", text: "A single thought—\"I sounded awkward\"—can shift your entire state. It tightens your body, changes how you speak, and changes how you see yourself.", order: 2),
                LessonContent(id: "content_1_1_4", text: "You begin responding not to the world as it is, but to the critical story you have started telling yourself.", order: 3)
            ]
        ),
        allLessons: []
    )
}
