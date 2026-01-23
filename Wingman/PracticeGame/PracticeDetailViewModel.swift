//
//  PracticeDetailViewModel.swift
//  Wingman
//
//  Created by Adnan Khan on 23/01/2026.
//


//
//  PracticeDetailViewModel.swift
//  Wingman
//
//  Created by Claude on 23/01/2026.
//

import SwiftUI
import Foundation
import Combine

@MainActor
final class PracticeDetailViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var practiceDetail: PracticeDetail?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // MARK: - Properties
    let practice: Practice
    
    // MARK: - Dependencies
    private let practiceService: PracticeServiceProtocol
    
    // MARK: - Initialization
    init(
        practice: Practice,
        practiceService: PracticeServiceProtocol = PracticeService()
    ) {
        self.practice = practice
        self.practiceService = practiceService
    }
    
    // MARK: - Fetch Practice Detail
    func fetchPracticeDetail() async {
        isLoading = true
        errorMessage = nil
        
        do {
            practiceDetail = try await practiceService.fetchPracticeDetail(practiceId: practice.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Start Practice
    func startPractice() {
        // Handle starting the practice
        // This could navigate to a practice session view
        // or trigger audio/video playback
    }
    
    // MARK: - Mark Practice Complete
    func markPracticeComplete(userId: UUID) async {
        guard let service = practiceService as? PracticeService else { return }
        
        do {
            try await service.completePractice(practiceId: practice.id, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Preview Helper
extension PracticeDetailViewModel {
    static func preview(practice: Practice = Practice.mockData[0]) -> PracticeDetailViewModel {
        let viewModel = PracticeDetailViewModel(
            practice: practice,
            practiceService: MockPracticeService()
        )
        viewModel.practiceDetail = PracticeDetail(
            id: UUID(),
            practiceId: practice.id,
            content: "This practice helps you understand that you are not your thoughts. Learn to observe your mental patterns without attachment and discover the space of awareness that exists beyond thinking.",
            videoUrl: nil,
            audioUrl: nil,
            duration: 15,
            steps: [
                PracticeStep(id: UUID(), title: "Find a Quiet Space", description: "Choose a comfortable, quiet location where you won't be disturbed.", order: 1),
                PracticeStep(id: UUID(), title: "Close Your Eyes", description: "Gently close your eyes and take three deep breaths to center yourself.", order: 2),
                PracticeStep(id: UUID(), title: "Observe Your Thoughts", description: "Notice thoughts as they arise without judging or engaging with them.", order: 3)
            ]
        )
        return viewModel
    }
}
