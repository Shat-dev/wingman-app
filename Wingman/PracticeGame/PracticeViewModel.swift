//
//  PracticeViewModel.swift
//  Wingman
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

    // MARK: - Init
    init(practiceService: PracticeServiceProtocol = PracticeService()) {
        self.practiceService = practiceService
    }

    // MARK: - Fetch Practices from DB
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

    // MARK: - Fetch Game Data for selected practice
    func fetchGameData(for practice: Practice) async -> PracticeGameData? {
        do {
            return try await practiceService.fetchGameData(
                scenarioId: practice.id,
                womanName: practice.womanName
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Fetch Practice Detail (for detail view)
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
        let vm = PracticeViewModel(practiceService: MockPracticeService())
        vm.practices = Practice.mockData
        return vm
    }
}
