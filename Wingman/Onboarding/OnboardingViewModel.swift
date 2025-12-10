//
//  OnboardingViewModel.swift
//  Wingman
//
//  Created by Adnan Khan on 29/11/2025.
//

import Foundation
import Combine

class OnboardingViewModel: ObservableObject {
    @Published var currentPage = 0
    
    // Dummy data — replace later
    let pages: [OnboardingModel] = [
        OnboardingModel(title: AppStrings.Onboarding.title1,
                        description: AppStrings.Onboarding.description1,
                       imageName: "onboard_img_1"),
        
        OnboardingModel(title: AppStrings.Onboarding.title2,
                       description: AppStrings.Onboarding.description2,
                       imageName: "onboard_img_2"),

        OnboardingModel(title: AppStrings.Onboarding.title3,
                       description: AppStrings.Onboarding.description3,
                       imageName: "onboard_img_3"),

        OnboardingModel(title: AppStrings.Onboarding.title4,
                       description: AppStrings.Onboarding.description4,
                       imageName: "onboard_img_4"),
    ]
    
    var isLastPage: Bool {
        currentPage == pages.count - 1
    }
    
    func next() {
        if currentPage < pages.count - 1 {
            currentPage += 1
        }
    }
    
    func skip() {
        // For now print — later navigate to LoginView
        print("Skipped onboarding")
    }
}
