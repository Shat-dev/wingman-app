//
//  PracticeViewModel.swift
//  Wingman
//
//  Created by Adnan Khan on 23/01/2026.
//


//
//  PracticeViewModel.swift
//  Wingman
//
//  Created by Claude on 23/01/2026.
//

import Foundation
import Combine

@MainActor
final class PracticeViewModel: ObservableObject {
    
    // MARK: - Published Properties
    @Published var practices: [Practice] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedPractice: Practice?
    
    // MARK: - Dependencies
    private let practiceService: PracticeServiceProtocol
    
    // MARK: - Initialization
    init(practiceService: PracticeServiceProtocol = PracticeService()) {
        self.practiceService = practiceService
    }
    
    // MARK: - Fetch Practices
    func fetchPractices() async {
        isLoading = true
        errorMessage = nil
        
        do {
            practices = try await practiceService.fetchPractices()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    // MARK: - Select Practice
    func selectPractice(_ practice: Practice) {
        guard !practice.isLocked else { return }
        selectedPractice = practice
    }
    
    // MARK: - Fetch Practice Detail
    func fetchPracticeDetail(for practice: Practice) async -> PracticeDetail? {
        do {
            return try await practiceService.fetchPracticeDetail(practiceId: practice.id)
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

// MARK: - Preview Helper
extension PracticeViewModel {
    static var preview: PracticeViewModel {
        let viewModel = PracticeViewModel(practiceService: MockPracticeService())
        viewModel.practices = Practice.mockData
        return viewModel
    }
}