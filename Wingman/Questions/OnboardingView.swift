//
//  QuestionFlowView.swift
//  Wingman
//
//  Created by Adnan Khan on 30/11/2025.
//
import SwiftUI
import Combine

struct OnboardingView: View {
    @State private var stepIndex: Int = 0
    @State private var selectedOption: String? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager
    
    let steps: [OnboardingStep] = onboardingSteps
    
    var body: some View {
        let step = steps[stepIndex]
        
        VStack(spacing: 0) {
            
            // MARK: - Top Row: Back Chevron + Progress Bar inline
            HStack(spacing: 12) {
                Button {
                    if stepIndex > 0 {
                        stepIndex -= 1
                    } else {
                        dismiss()
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 44, height: 44, alignment: .center)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                
                progressBar(progress: CGFloat(step.progress))
                    .frame(height: 10)
            }
            .padding(.top, 8)
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            
            // MARK: - Content
            VStack(alignment: .leading, spacing: 20) {
                
                // Title + Subtitle
                Text(step.title)
                    .font(.manropeSemiBold(size: 24))
                
                
                if let subtitle = step.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                // MARK: – If question screen
                if step.type == .question {
                    
                    if let options = step.options {
                        VStack(spacing: 10) {
                            ForEach(options, id: \.self) { option in
                                Button(action: {
                                    selectedOption = option
                                }) {
                                    OptionButton(text: option, isSelected: selectedOption == option)
                                }
                            }
                        }
                    }
                    
                } else {
                    // MARK: – Statistic screen
                    if let chartImage = step.chartImage {
                        Image(chartImage)
                            .resizable()
                            .scaledToFit()
                            .padding(.vertical)
                    }
                }
                
                Spacer()
                
                // Bottom Buttons
                VStack(spacing: 12) {
                    
                    Button("Next") {
                        moveToNext()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(5)
                    .opacity(step.type == .question && selectedOption == nil ? 0.4 : 1)
                    .disabled(step.type == .question && selectedOption == nil)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .navigationBarBackButtonHidden(true)
        .animation(.easeInOut, value: stepIndex)
    }
    
    // MARK: - Progress Bar View
    private func progressBar(progress: CGFloat) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 10)

                Capsule()
                    .fill(Color.black)
                    .frame(width: geo.size.width * max(0, min(1, progress)), height: 10)
                    .animation(.easeInOut(duration: 0.25), value: progress)
            }
        }
        .frame(height: 10)
    }
    
    func moveToNext() {
        // Save the selected answer (you can store this in an array or upload to Supabase later)
        if let answer = selectedOption {
            print("Question \(stepIndex + 1): \(answer)")
            // TODO: Save to array or Supabase
        }
        
        selectedOption = nil
        
        if stepIndex < steps.count - 1 {
            stepIndex += 1
        } else {
            // All questions completed
            print("✅ Finished all questions")
            authManager.completeQuestions()
            // Navigation will happen automatically via RootView
        }
    }
}

struct QuestionFlowView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
            .environmentObject(AuthManager())
    }
}
