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
                    // Checkmark
                    Image("checklist")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 291, height: 291)
                        .clipped()
                        .allowsHitTesting(false)
                }
                .padding(.bottom, 5)
                
                // MARK: - Title
                Text("Lesson Complete!")
                    .font(.manropeSemiBold(size: 28))
                    .foregroundColor(.black)
                    .kerning(-0.3)
                    .padding(.bottom, 20)
                
                // MARK: - Up Next Section
                if let nextLesson = nextLessonInfo {
                    VStack(spacing: 8) {
                        Text("Up Next")
                            .font(.manropeMedium(size: 14))
                            .foregroundColor(Color.black.opacity(0.7))
                        
                        Text(nextLesson.title)
                            .font(.manropeMedium(size: 14))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 50)
                } else {
                    VStack(spacing: 10) {
                        Text("")
                            .font(.system(size: 32))
                        
                        Text("Course Complete!")
                            .font(.manropeMedium(size: 14))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                
                Spacer()
                
                // MARK: - Continue Button
                Button(action: {
                    HapticManager.shared.mediumImpact()
                    onContinue()
                    dismiss()
                }) {
                    Text("Continue")
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.black)
                        .cornerRadius(5)
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
            subtitle: "Beliefs & Reframes"
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
