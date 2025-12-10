//
//  QuestionFlowView.swift
//  Wingman
//
//  Created by Adnan Khan on 30/11/2025.
//
import SwiftUI
import Combine

struct QuestionFlowView: View {
    @State private var stepIndex: Int = 0
    @State private var selectedOption: String? = nil
    @Environment(\.dismiss) private var dismiss
    
    let steps: [QuestionStep] = questionnaireSteps
    
    var body: some View {
        let step = steps[stepIndex]
        
        VStack(spacing: 0) {
            
            // MARK: - Top Row: Back Chevron + Progress Bar inline
            HStack(spacing: 12) {
                Button {
                    if stepIndex > 0 {
                        stepIndex -= 1
                    } else {
                        // Pop back to previous screen in the same NavigationStack
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
                    .font(.title2)
                    .bold()
                
                if let subtitle = step.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                // MARK: — If question screen
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
                    // MARK: — Statistic screen
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
                    
                    // Skip (only for questions)
                    if step.type == .question {
                        Button("Skip") {
                            moveToNext()
                        }
                        .font(.footnote)
                        .foregroundColor(.gray)
                    }
                    
                    Button("Next") {
                        // save selectedOption someday → API
                        moveToNext()
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .opacity(step.type == .question && selectedOption == nil ? 0.4 : 1)
                    .disabled(step.type == .question && selectedOption == nil)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .navigationBarBackButtonHidden(true) // Hide the system back button
        .animation(.easeInOut, value: stepIndex)
    }
    
    // MARK: - Progress Bar View (same as in AuthView)
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
        selectedOption = nil
        
        if stepIndex < steps.count - 1 {
            stepIndex += 1
        } else {
            print("Finished all questions")
        }
    }
}
struct QuestionFlowView_Previews: PreviewProvider {
    static var previews: some View {
        QuestionFlowView()
    }
}
