// MARK: - Models (Ready for Supabase)
import SwiftUI
import Combine
import Foundation
import Supabase

struct PracticeGameData: Identifiable, Codable {
    let id: String
    let title: String
    let scenes: [GameScene]
}

struct GameScene: Identifiable, Codable {
    let id: String
    let type: SceneType
    let characterName: String?
    let text: String
    let imageName: String?
    let options: [GameOption]?
    let order: Int
    
    enum SceneType: String, Codable {
        case context
        case userDialogue
        case womanDialogue
        case options
        case feedback
    }
}

struct GameOption: Identifiable, Codable {
    let id: String
    let text: String
    let nextSceneId: String?
    let isCorrect: Bool
}

// MARK: - ViewModel
class PracticeGameViewModel: ObservableObject {
    @Published var currentSceneIndex: Int = 0
    @Published var gameCompleted: Bool = false
    @Published var progress: Double = 0.0
    
    let gameData: PracticeGameData
    let userName: String
    
    private var sortedScenes: [GameScene] {
        gameData.scenes.sorted { $0.order < $1.order }
    }
    
    var currentScene: GameScene? {
        guard currentSceneIndex < sortedScenes.count else { return nil }
        return sortedScenes[currentSceneIndex]
    }
    
    var totalScenes: Int {
        sortedScenes.count
    }
    
    init(gameData: PracticeGameData, userName: String = "You") {
        self.gameData = gameData
        self.userName = userName
        updateProgress()
    }
    
    func goToNextScene() {
        if currentSceneIndex < sortedScenes.count - 1 {
            currentSceneIndex += 1
            updateProgress()
        } else {
            gameCompleted = true
        }
    }
    
    func goToPreviousScene() {
        if currentSceneIndex > 0 {
            currentSceneIndex -= 1
            updateProgress()
        }
    }
    
    func selectOption(_ option: GameOption) {
        // If option specifies next scene, jump to it
        if let nextSceneId = option.nextSceneId,
           let nextIndex = sortedScenes.firstIndex(where: { $0.id == nextSceneId }) {
            currentSceneIndex = nextIndex
        } else {
            // Otherwise just go to next scene
            goToNextScene()
        }
        updateProgress()
    }
    
    func retryCurrentScene() {
        // Stay on same scene, just for retry action
        updateProgress()
    }
    
    private func updateProgress() {
        progress = Double(currentSceneIndex + 1) / Double(totalScenes)
    }
}

// MARK: - Main Game View
struct PracticeGame: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PracticeGameViewModel
    @State private var showGameComplete = false
    
    init(gameData: PracticeGameData = MockData.sampleGame, userName: String = "You") {
        _viewModel = StateObject(wrappedValue: PracticeGameViewModel(gameData: gameData, userName: userName))
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
                            viewModel.goToNextScene()
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
            if completed {
                showGameComplete = true
            }
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
                            .onTapGesture {
                                onTapBack()
                            }
                        
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
                    
                    
                    // Character Image (1:1 aspect ratio, centered) with independent horizontal margins
                    // Only show image for non-options scenes
                    if scene.type != .options, let imageName = scene.imageName {
                        ZStack {
                            Image(imageName)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                        }
                        .padding(.horizontal, 20) // 20pt left/right margin only for the image
                        .padding(.top, 10)
                        .padding(.bottom, 70)
                    }
                    
                    
                    
                    // Scene Content Based on Type
                    switch scene.type {
                    case .options:
                        // Center options vertically in full available space
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
        case .userDialogue:
            return userName
        case .womanDialogue:
            return scene.characterName ?? "Sophie"
        case .feedback:
            return "Feedback"
        default:
            return ""
        }
    }
    
    private var actionText: String {
        scene.type == .feedback ? "Tap to retry" : "Tap to continue"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Character name ABOVE the bubble:
            if scene.type == .userDialogue || scene.type == .feedback {
                Text(displayName)
                    .font(.manropeMedium(size: 18))
                    .foregroundColor(.black.opacity(0.6))
                    .padding(.leading, 10)
            } else if scene.type == .womanDialogue {
                HStack {
                    Spacer()
                    Text(displayName)
                        .font(.manropeMedium(size: 18))
                        .foregroundColor(.black.opacity(0.6))
                        .padding(.trailing, 10)
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
            ForEach(options) { option in
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
                        )
                }
                .buttonStyle(.plain)
            }
            
            Text("Choose an option to continue")
                .font(.manropeMedium(size: 14))
                .foregroundColor(.black.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 1)
                .padding(.trailing,8)
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
                
                
                // Checklist image from assets
                Image("checklist")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 290, height: 290)
                    .padding(.top, 50)
                
                
                Text("Game Complete!")
                    .font(.manropeSemiBold(size: 24))
                    .foregroundColor(.black)
                
                Spacer()
                
                // Continue button
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

// MARK: - Mock Data
struct MockData {
    static let sampleGame = PracticeGameData(
        id: "game_1",
        title: "Practice Scenario 1",
        scenes: [
            // Scene 1: Context
            GameScene(
                id: "scene_1",
                type: .context,
                characterName: nil,
                text: "Hey I know this is super random but I just had to come up and say hi",
                imageName: "game_person_m",
                options: nil,
                order: 0
            ),
            
            // Scene 2: Options
            GameScene(
                id: "scene_2",
                type: .options,
                characterName: nil,
                text: "",
                imageName: "nil",
                options: [
                    GameOption(id: "opt_1", text: "Say hi", nextSceneId: "scene_3", isCorrect: true),
                    GameOption(id: "opt_2", text: "Go up behind her and slap them cheeks", nextSceneId: "scene_5", isCorrect: false)
                ],
                order: 1
            ),
            
            // Scene 3: User Dialogue (Correct choice)
            GameScene(
                id: "scene_3",
                type: .userDialogue,
                characterName: nil,
                text: "Hey I know this is super random but I just had to come up and say hi",
                imageName: "game_person_m",
                options: nil,
                order: 2
            ),
            
            // Scene 4: Woman Dialogue
            GameScene(
                id: "scene_4",
                type: .womanDialogue,
                characterName: "Sophie",
                text: "Inclusion reduces social tension and preserves control. Acknowledge her friends.",
                imageName: "game_person_f",
                options: nil,
                order: 3
            ),
            
            // Scene 5: Feedback (Wrong choice)
            GameScene(
                id: "scene_5",
                type: .feedback,
                characterName: nil,
                text: "While being direct sometimes works, it may come across as too forward in a cafe.",
                imageName: "game_person_m",
                options: nil,
                order: 4
            )
        ]
    )
    
    static let sampleGame2 = PracticeGameData(
        id: "game_2",
        title: "Practice Scenario 2",
        scenes: [
            GameScene(
                id: "scene_1",
                type: .context,
                characterName: nil,
                text: "You see an attractive woman reading a book at a coffee shop.",
                imageName: "book.circle",
                options: nil,
                order: 0
            ),
            
            GameScene(
                id: "scene_2",
                type: .options,
                characterName: nil,
                text: "",
                imageName: "book.circle",
                options: [
                    GameOption(id: "opt_1", text: "\"Hey good looking, let me sit with you.\"", nextSceneId: "scene_5", isCorrect: false),
                    GameOption(id: "opt_2", text: "Each approach feels higher-stakes because it's rare", nextSceneId: "scene_3", isCorrect: true),
                    GameOption(id: "opt_3", text: "Each approach feels higher-stakes because it's rare", nextSceneId: "scene_5", isCorrect: false)
                ],
                order: 1
            ),
            
            GameScene(
                id: "scene_3",
                type: .userDialogue,
                characterName: nil,
                text: "Is that book any good? I've been meaning to read it.",
                imageName: "book.circle",
                options: nil,
                order: 2
            ),
            
            GameScene(
                id: "scene_4",
                type: .womanDialogue,
                characterName: "Sophie",
                text: "Oh yes! It's really interesting. Are you into psychology?",
                imageName: "game_person_f",
                options: nil,
                order: 3
            ),
            
            GameScene(
                id: "scene_5",
                type: .feedback,
                characterName: nil,
                text: "Too direct. A softer, more curious approach works better.",
                imageName: "game_person_m",
                options: nil,
                order: 4
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
