// e.g., OnBoardingData.swift
import Foundation

let onboardingSteps: [OnboardingStep] = [
    OnboardingStep(
        type: .question,
        title: "How old are you?",
        subtitle: nil,
        options: ["Under 18", "18-24", "25-34", "35-44", "45+"],
        chartImage: nil,
        progress: 0.16
    ),
    OnboardingStep(
        type: .question,
        title: "When was the last time you spoke to a woman in public?",
        subtitle: nil,
        options: ["Within the past", "Within the past month", "More than a year ago", "Never approached before"],
        chartImage: nil,
        progress: 0.32
    ),
    OnboardingStep(
        type: .question,
        title: "Do you often want to approach women in public but stop yourself?",
        subtitle: nil,
        options: ["Yes, almost every time", "Sometimes", "Rarely", "No, I usually go for it"],
        chartImage: nil,
        progress: 0.48
    ),
    OnboardingStep(
        type: .question,
        title: "What usually stops you from doing so?",
        subtitle: nil,
        options: ["Fear of rejection or being embarrased, almost every time", "Fear of social consequences", "Not knowing what to say or how to start", "Worrying about coming across wrong", "Other"],
        chartImage: nil,
        progress: 0.64
    ),
    OnboardingStep(
        type: .question,
        title: "What are you mainly hoping to improve?",
        subtitle: nil,
        options: ["Better mindset & confidence", "Learning how to approach ", "Keeping conversations going", "Creating attraction and romantic interest", "Other"],
        chartImage: nil,
        progress: 0.8
    )
]
