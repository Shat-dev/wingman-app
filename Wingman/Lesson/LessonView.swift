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
    @State private var currentPage: Int = 0 // Which "page" we're on
    @State private var showLessonComplete = false
    @State private var availableHeight: CGFloat = 0
    
    // Content items sorted by order
    private var sortedContent: [LessonContent] {
        lesson.content.sorted { $0.order < $1.order }
    }
    
    // Total segments for progress bar
    private var totalSegments: Int {
        sortedContent.count
    }
    
    // Currently visible content (accumulated up to currentContentIndex)
    private var visibleContent: [LessonContent] {
        guard currentContentIndex >= 0 else { return [] }
        return Array(sortedContent.prefix(currentContentIndex + 1))
    }
    
    // Content visible on CURRENT page only
    private var currentPageContent: [LessonContent] {
        let pageBreaks = calculatePageBreaks()
        
        if currentPage >= pageBreaks.count {
            return []
        }
        
        let startIndex = pageBreaks[currentPage].startIndex
        let endIndex = pageBreaks[currentPage].endIndex
        
        return Array(visibleContent[startIndex...endIndex])
    }
    
    // Progress as a percentage (0.0 to 1.0)
    private var progress: Double {
        guard totalSegments > 0 else { return 0 }
        if currentContentIndex < 0 { return 0 }
        return Double(currentContentIndex + 1) / Double(totalSegments)
    }
    
    var body: some View {
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
                            // Content Screen with Page Transition
                            ContentScreenView(
                                content: currentPageContent,
                                pageIndex: currentPage
                            )
                            .id("page_\(currentPage)") // Force re-render on page change
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
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
                    .onAppear {
                        availableHeight = geometry.size.height
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
                    LessonDataService.shared.markLessonCompleted(
                        lessonId: lesson.id,
                        courseId: lesson.courseId
                    )
                    dismiss()
                }
            )
        }
    }
    
    // MARK: - Calculate Page Breaks
    struct PageBreak {
        let startIndex: Int
        let endIndex: Int
    }
    
    private func calculatePageBreaks() -> [PageBreak] {
        guard !visibleContent.isEmpty, availableHeight > 0 else {
            return []
        }
        
        var breaks: [PageBreak] = []
        var currentPageStart = 0
        var accumulatedHeight: CGFloat = 0
        let maxHeight = availableHeight - 100 // Safety margin for padding
        
        let font = UIFont(name: "Manrope-Regular", size: 18) ?? UIFont.systemFont(ofSize: 18)
        let width = UIScreen.main.bounds.width - 48 // 24pt padding each side
        
        for (index, content) in visibleContent.enumerated() {
            let textHeight = content.text.heightWithConstraints(
                width: width,
                font: font,
                lineSpacing: 8
            )
            
            let itemHeight = textHeight + (index > currentPageStart ? 20 : 0) // Add spacing between items
            
            // Check if adding this item would overflow the page
            if accumulatedHeight + itemHeight > maxHeight && index > currentPageStart {
                // Save current page
                breaks.append(PageBreak(
                    startIndex: currentPageStart,
                    endIndex: index - 1
                ))
                
                // Start new page
                currentPageStart = index
                accumulatedHeight = textHeight
            } else {
                accumulatedHeight += itemHeight
            }
        }
        
        // Add final page
        if currentPageStart < visibleContent.count {
            breaks.append(PageBreak(
                startIndex: currentPageStart,
                endIndex: visibleContent.count - 1
            ))
        }
        
        return breaks
    }
    
    // MARK: - Navigation Functions
    private func goBack() {
        if currentContentIndex > -1 {
            // Check if we're at the start of a page
            let pageBreaks = calculatePageBreaks()
            let isAtPageStart = currentPage < pageBreaks.count &&
                                currentContentIndex == pageBreaks[currentPage].startIndex
            
            if isAtPageStart && currentPage > 0 {
                // Move to previous page
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentPage -= 1
                    currentContentIndex -= 1
                }
                print("⬅️ Previous page (\(currentPage + 1))")
            } else {
                // Just remove last line
                currentContentIndex -= 1
                print("⬅️ Back to index: \(currentContentIndex)")
            }
        }
    }
    
    private func goForward() {
        if currentContentIndex < sortedContent.count - 1 {
            currentContentIndex += 1
            
            // Check if we need to move to next page
            let pageBreaks = calculatePageBreaks()
            
            // Find which page the current content index belongs to
            var targetPage = 0
            for (pageIndex, pageBreak) in pageBreaks.enumerated() {
                if currentContentIndex <= pageBreak.endIndex {
                    targetPage = pageIndex
                    break
                }
            }
            
            // If target page is different from current page, animate transition
            if targetPage != currentPage {
                withAnimation(.easeInOut(duration: 0.3)) {
                    currentPage = targetPage
                }
                print("➡️ Next page (\(currentPage + 1)) - showing content \(currentContentIndex + 1)")
            } else {
                print("➡️ Forward to index: \(currentContentIndex)")
            }
        } else {
            // Lesson complete
            print("✅ Lesson complete!")
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
                    .font(.manropeRegular(size: 15))
                    .foregroundColor(Color(hex: "888888"))
                Spacer()
            }
            .frame(maxWidth: .infinity)
            
            // Forward label
            VStack {
                Spacer()
                Text("Forward")
                    .font(.manropeRegular(size: 15))
                    .foregroundColor(.black)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Content Screen View
struct ContentScreenView: View {
    let content: [LessonContent]
    let pageIndex: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(content.enumerated()), id: \.element.id) { index, item in
                Text(item.text)
                    .font(.manropeRegular(size: 18))
                    .foregroundColor(.black)
                    .lineSpacing(8)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, index == content.count - 1 ? 0 : 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.horizontal, 24)
        .padding(.top, 40)
        .padding(.bottom, 60)
    }
}

// MARK: - String Extension for Height Calculation
extension String {
    func heightWithConstraints(width: CGFloat, font: UIFont, lineSpacing: CGFloat) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = lineSpacing
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraphStyle
        ]
        
        let attributedString = NSAttributedString(string: self, attributes: attributes)
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = attributedString.boundingRect(
            with: constraintRect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        
        return ceil(boundingBox.height)
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
            courseSummary: "Learn to strengthen confidence by reframing limiting beliefs.",
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
