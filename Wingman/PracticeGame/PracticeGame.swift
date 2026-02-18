//
//  PracticeGame.swift
//  Wingman
//

import SwiftUI
import Combine
import Foundation
import Supabase

// MARK: - ViewModel
@MainActor
class PracticeGameViewModel: ObservableObject {

    // MARK: - Published
    @Published var currentSceneIndex: Int = 0
    @Published var gameCompleted: Bool = false
    @Published var progress: Double = 0.0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Data
    let gameData: PracticeGameData
    let userName: String
    private let scenarioId: UUID?
    private let practiceService: PracticeServiceProtocol

    // MARK: - Computed
    private var sortedScenes: [GameScene] {
        gameData.scenes.sorted { $0.order < $1.order }
    }

    var currentScene: GameScene? {
        guard currentSceneIndex < sortedScenes.count else { return nil }
        return sortedScenes[currentSceneIndex]
    }

    var totalScenes: Int { sortedScenes.count }

    // MARK: - Init
    init(
        gameData: PracticeGameData,
        userName: String = "You",
        scenarioId: UUID? = nil,
        practiceService: PracticeServiceProtocol = PracticeService()
    ) {
        self.gameData = gameData
        self.userName = userName
        self.scenarioId = scenarioId ?? UUID(uuidString: gameData.id)
        self.practiceService = practiceService
        updateProgress()
    }

    // MARK: - Navigation
    func goToNextScene() {
        if currentSceneIndex < sortedScenes.count - 1 {
            currentSceneIndex += 1
            updateProgress()
            persistProgress()
        } else {
            gameCompleted = true
            markComplete()
        }
    }

    func goToPreviousScene() {
        if currentSceneIndex > 0 {
            currentSceneIndex -= 1
            updateProgress()
        }
    }

    // MARK: - Option selected (branching)
    func selectOption(_ option: GameOption) {
        if let nextId = option.nextSceneId,
           let nextIndex = sortedScenes.firstIndex(where: { $0.id == nextId }) {
            currentSceneIndex = nextIndex
        } else {
            goToNextScene()
        }
        updateProgress()
        persistProgress()
    }

    // MARK: - Retry — jump back to the retry target question
    func retryCurrentScene() {
        guard let scene = currentScene,
              scene.type == .feedback,
              let retryId = scene.retryTargetScreenId,
              let retryIndex = sortedScenes.firstIndex(where: { $0.id == retryId }) else {
            // Fallback: just advance
            goToNextScene()
            return
        }
        currentSceneIndex = retryIndex
        updateProgress()
    }

    // MARK: - Private helpers
    private func updateProgress() {
        progress = Double(currentSceneIndex + 1) / Double(totalScenes)
    }

    private func persistProgress() {
        guard let sceneId = currentScene.flatMap({ UUID(uuidString: $0.id) }),
              let scenarioId = scenarioId,
              let userIdStr = SupabaseManager.shared.currentUserId,
              let userId = UUID(uuidString: userIdStr) else { return }

        Task {
            try? await practiceService.saveScenarioProgress(
                userId: userId,
                scenarioId: scenarioId,
                currentScreenId: sceneId
            )
        }
    }

    private func markComplete() {
        guard let scenarioId = scenarioId,
              let userIdStr = SupabaseManager.shared.currentUserId,
              let userId = UUID(uuidString: userIdStr) else { return }

        Task {
            try? await practiceService.completeScenario(userId: userId, scenarioId: scenarioId)
        }
    }
}

// MARK: - Main Game View
struct PracticeGame: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PracticeGameViewModel
    @State private var showGameComplete = false

    init(
        gameData: PracticeGameData = MockData.sampleGame,
        userName: String = "You",
        scenarioId: UUID? = nil
    ) {
        _viewModel = StateObject(
            wrappedValue: PracticeGameViewModel(
                gameData: gameData,
                userName: userName,
                scenarioId: scenarioId
            )
        )
    }

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Top Navigation Bar with Progress
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(width: 44, height: 44, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 10)
                            Capsule()
                                .fill(Color.black)
                                .frame(width: geometry.size.width * CGFloat(viewModel.progress), height: 10)
                                .animation(.easeInOut(duration: 0.25), value: viewModel.progress)
                        }
                    }
                    .frame(height: 10)

                    Spacer()
                        .frame(width: 15)
                }
                .padding(.top, 8)
                .padding(.leading, 20)
                .padding(.trailing, 44)
                .padding(.bottom, 12)

                // MARK: - Game Content Area
                if let scene = viewModel.currentScene {
                    GameSceneView(
                        scene: scene,
                        userName: viewModel.userName,
                        onTapContinue: {
                            viewModel.goToNextScene()
                        },
                        onTapRetry: {
                            viewModel.retryCurrentScene()
                        },
                        onSelectOption: { option in
                            viewModel.selectOption(option)
                        },
                        onTapBack: {
                            viewModel.goToPreviousScene()
                        }
                    )
                }
            }
        }
        .navigationBarHidden(true)
        .onChange(of: viewModel.gameCompleted) { completed in
            if completed { showGameComplete = true }
        }
        .fullScreenCover(isPresented: $showGameComplete) {
            GameCompleteView {
                dismiss()
            }
        }
    }
}

// MARK: - Game Scene View (Handles all scene types)
struct GameSceneView: View {
    let scene: GameScene
    let userName: String
    let onTapContinue: () -> Void
    let onTapRetry: () -> Void
    let onSelectOption: (GameOption) -> Void
    let onTapBack: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Tap areas for navigation (only for non-option screens)
                if scene.type != .options {
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture { onTapBack() }

                        Rectangle()
                            .fill(Color.clear)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if scene.type == .feedback {
                                    onTapRetry()
                                } else {
                                    onTapContinue()
                                }
                            }
                    }
                }

                // Content
                VStack(spacing: 0) {
                    // Character Image (1:1 aspect ratio, centered)
                    // Only show image for non-options scenes
                    if scene.type != .options, let imageName = scene.imageName {
                        ZStack {
                            Image(imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 70)
                    }

                    // Scene Content Based on Type
                    switch scene.type {
                    case .options:
                        Spacer(minLength: 0)
                        OptionsContentView(
                            options: scene.options ?? [],
                            onSelectOption: onSelectOption
                        )
                        .padding(.horizontal, 24)
                        Spacer(minLength: 0)

                    case .context, .userDialogue, .womanDialogue, .feedback:
                        DialogueContentView(
                            scene: scene,
                            userName: userName
                        )
                        .padding(.horizontal, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
    }
}

// MARK: - Dialogue Content View (Context, User, Woman, Feedback)
struct DialogueContentView: View {
    let scene: GameScene
    let userName: String

    private var displayName: String {
        switch scene.type {
        case .userDialogue: return userName
        case .womanDialogue: return scene.characterName ?? "Sophie"
        case .feedback: return "Feedback"
        default: return ""
        }
    }

    private var actionText: String {
        scene.type == .feedback ? "Tap to retry" : "Tap to continue"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Character name ABOVE the bubble
            if scene.type == .userDialogue || scene.type == .feedback {
                Text(displayName)
                    .font(.manropeMedium(size: 18))
                    .foregroundColor(.black.opacity(0.6))
                    .padding(.leading, 8)
            } else if scene.type == .womanDialogue {
                HStack {
                    Spacer()
                    Text(displayName)
                        .font(.manropeMedium(size: 18))
                        .foregroundColor(.black.opacity(0.6))
                        .padding(.trailing, 8)
                }
            }

            // Text container (dialogue bubble)
            VStack(alignment: .leading, spacing: 0) {
                Text(scene.text)
                    .font(.manropeMedium(size: 14))
                    .foregroundColor(.black)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 30)
            }
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.white)
                    )
                    .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 2)
            )

            // Action text
            Text(actionText)
                .font(.manropeMedium(size: 14))
                .foregroundColor(.black.opacity(0.5))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 5)
                .padding(.trailing, 8)
        }
    }
}

// MARK: - Options Content View
struct OptionsContentView: View {
    let options: [GameOption]
    let onSelectOption: (GameOption) -> Void

    var body: some View {
        VStack(spacing: 12) {
            ForEach(options.sorted { $0.orderIndex < $1.orderIndex }) { option in
                Button {
                    onSelectOption(option)
                } label: {
                    Text(option.text)
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.black.opacity(0.1), lineWidth: 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(Color.white)
                                )
                                .shadow(color: Color.black.opacity(0.06), radius: 5, x: 0, y: 2)
                        )
                }
                .buttonStyle(.plain)
            }

            Text("Choose an option to continue")
                .font(.manropeMedium(size: 14))
                .foregroundColor(.black.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 1)
                .padding(.trailing, 8)
        }
    }
}

// MARK: - Game Complete View
struct GameCompleteView: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                Image("checklist")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 290, height: 290)
                    .padding(.top, 50)

                Text("Game Complete!")
                    .font(.manropeSemiBold(size: 24))
                    .foregroundColor(.black)

                Spacer()

                Button {
                    onContinue()
                } label: {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.black)
                        .cornerRadius(5)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
}

// MARK: - Mock Data (for SwiftUI previews only)
struct MockData {
    static let sampleGame = PracticeGameData(
        id: "00000000-0000-0000-0000-000000000001",
        title: "Practice Scenario 1",
        scenes: [
            GameScene(
                id: "scene_1",
                type: .context,
                characterName: nil,
                text: "You spot an attractive woman standing alone at the bar. She glances your way.",
                imageName: "game_person_m",
                options: nil,
                order: 0,
                defaultNextScreenId: "scene_2",
                retryTargetScreenId: nil
            ),
            GameScene(
                id: "scene_2",
                type: .options,
                characterName: nil,
                text: "",
                imageName: nil,
                options: [
                    GameOption(id: "opt_1", text: "Walk over with relaxed confidence and say hi", nextSceneId: "scene_3", isCorrect: true, orderIndex: 0),
                    GameOption(id: "opt_2", text: "Go up behind her and tap her shoulder aggressively", nextSceneId: "scene_5", isCorrect: false, orderIndex: 1),
                    GameOption(id: "opt_3", text: "Wait and hope she approaches you", nextSceneId: "scene_5", isCorrect: false, orderIndex: 2)
                ],
                order: 1,
                defaultNextScreenId: nil,
                retryTargetScreenId: nil
            ),
            GameScene(
                id: "scene_3",
                type: .userDialogue,
                characterName: nil,
                text: "Hey, I know this is random — but I had to come say hi.",
                imageName: "game_person_m",
                options: nil,
                order: 2,
                defaultNextScreenId: "scene_4",
                retryTargetScreenId: nil
            ),
            GameScene(
                id: "scene_4",
                type: .womanDialogue,
                characterName: "Sophie",
                text: "Ha, that's actually kind of sweet. I'm Sophie.",
                imageName: "game_person_f",
                options: nil,
                order: 3,
                defaultNextScreenId: nil,
                retryTargetScreenId: nil
            ),
            GameScene(
                id: "scene_5",
                type: .feedback,
                characterName: nil,
                text: "Going in too strong before building any eye contact kills the vibe. Reset.",
                imageName: "game_person_m",
                options: nil,
                order: 4,
                defaultNextScreenId: nil,
                retryTargetScreenId: "scene_2"
            )
        ]
    )
}

// MARK: - Preview
#Preview {
    NavigationView {
        PracticeGame()
    }
}
