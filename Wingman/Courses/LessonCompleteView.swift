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
                
                // Checkmark icon
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.black, lineWidth: 2)
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(45))
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 50, weight: .medium))
                        .foregroundColor(.black)
                }
                .padding(.bottom, 40)
                
                // Title
                Text("Lesson Complete!")
                    .font(.manropeSemiBold(size: 28))
                    .foregroundColor(.black)
                    .padding(.bottom, 32)
                
                // Up Next section
                if let nextLesson = nextLessonInfo {
                    VStack(spacing: 8) {
                        Text("Up Next")
                            .font(.manropeRegular(size: 14))
                            .foregroundColor(.gray)
                        
                        Text(nextLesson.subtitle)
                            .font(.manropeRegular(size: 16))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    VStack(spacing: 8) {
                        Text("Course Complete!")
                            .font(.manropeRegular(size: 16))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                
                Spacer()
                
                // Continue button
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
            title: "Building Confidence",
            subtitle: "Courage Comes first, Confidence follows"
        ),
        onContinue: {}
    )
}
