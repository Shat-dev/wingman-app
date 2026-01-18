//
//  LessonCompleteView.swift
//  Wingman
//

import SwiftUI

struct LessonCompleteView: View {
    @Environment(\.dismiss) private var dismiss
    let nextLessonInfo: NextLessonInfo?
    let onContinue: () -> Void
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // MARK: - Checkmark Icon
                ZStack {
                    // Diamond shape (rotated rounded rectangle)
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.black, lineWidth: 2)
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(45))
                    
                    // Checkmark
                    Image(systemName: "checkmark")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundColor(.black)
                }
                .padding(.bottom, 40)
                
                // MARK: - Title
                Text("Lesson Complete!")
                    .font(.manropeSemiBold(size: 28))
                    .foregroundColor(.black)
                    .kerning(-0.3)
                    .padding(.bottom, 32)
                
                // MARK: - Up Next Section
                if let nextLesson = nextLessonInfo {
                    VStack(spacing: 10) {
                        Text("Up Next")
                            .font(.manropeRegular(size: 14))
                            .foregroundColor(Color("888888"))
                        
                        Text(nextLesson.title)
                            .font(.manropeMedium(size: 17))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    VStack(spacing: 10) {
                        Text("🎉")
                            .font(.system(size: 32))
                        
                        Text("Course Complete!")
                            .font(.manropeMedium(size: 17))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                
                Spacer()
                
                // MARK: - Continue Button
                Button(action: {
                    onContinue()
                    dismiss()
                }) {
                    Text("Continue")
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.black)
                        .cornerRadius(8)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }
}

#Preview {
    LessonCompleteView(
        nextLessonInfo: NextLessonInfo(
            title: "Rejection isn't personal",
            subtitle: "Courage Comes first, Confidence follows"
        ),
        onContinue: {}
    )
}

#Preview("Course Complete") {
    LessonCompleteView(
        nextLessonInfo: nil,
        onContinue: {}
    )
}
