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
    @Published var currentSceneId: String = ""
    @Published var gameCompleted: Bool = false
    @Published var progress: Double = 0.0

    // MARK: - Data
    let gameData: PracticeGameData
    let userName: String
    private let scenarioId: UUID?
    private let practiceService: PracticeServiceProtocol

    // Scenes keyed by id for O(1) lookup
    private var sceneMap: [String: GameScene] = [:]

    // The ordered "canonical" path (non-fail screens only) used purely for
    // progress bar calculation so the bar moves forward meaningfully.
    private let canonicalOrder: [String]

    var currentScene: GameScene? { sceneMap[currentSceneId] }

    var totalScenes: Int { canonicalOrder.count }

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

        // Build scene map
        var map: [String: GameScene] = [:]
        for scene in gameData.scenes { map[scene.id] = scene }
        self.sceneMap = map

        // Canonical order: scenes that are NOT fail/feedback branches
        // (i.e. ids not containing "_fail") sorted by their order field
        let mainPath = gameData.scenes
            .filter { !$0.id.contains("_fail") }
            .sorted { $0.order < $1.order }
        self.canonicalOrder = mainPath.map { $0.id }

        self.currentSceneId = gameData.startingScreenId
        updateProgress()
    }

    // MARK: - Navigate via tap-to-continue
    func goToNextScene() {
        guard let scene = currentScene else { return }

        // If this scene explicitly points to "complete", trigger game end
        if scene.defaultNextScreenId == "complete" || scene.defaultNextScreenId == nil && isFinalCanonicalScene(scene.id) {
            triggerCompletion()
            return
        }

        if let nextId = scene.defaultNextScreenId {
            currentSceneId = nextId
            updateProgress()
            persistProgress()
        } else {
            // No next defined — treat as end
            triggerCompletion()
        }
    }

    func goToPreviousScene() {
        // Back navigation: find the scene that leads to current scene
        if let prev = gameData.scenes.first(where: { $0.defaultNextScreenId == currentSceneId }) {
            currentSceneId = prev.id
            updateProgress()
            return
        }
        
        for scene in gameData.scenes {
            if let options = scene.options {
                for option in options {
                    if option.nextSceneId == currentSceneId {
                        currentSceneId = scene.id
                        updateProgress()
                        return
                    }
                }
            }
        }
    }

    // MARK: - Option selected
    func selectOption(_ option: GameOption) {
        HapticManager.shared.selection()
        if let nextId = option.nextSceneId {
            if nextId == "complete" {
                triggerCompletion()
                return
            }
            currentSceneId = nextId
            updateProgress()
            persistProgress()
        } else {
            goToNextScene()
        }
    }

    // MARK: - Retry (feedback screen tap)
    func retryCurrentScene() {
        guard let scene = currentScene, scene.type == .feedback else {
            goToNextScene()
            return
        }
        if let retryId = scene.retryTargetScreenId, sceneMap[retryId] != nil {
            currentSceneId = retryId
        } else if let nextId = scene.defaultNextScreenId, sceneMap[nextId] != nil {
            currentSceneId = nextId
        }
        updateProgress()
    }

    // MARK: - Progress (based on canonical path position)
    private func updateProgress() {
        guard !canonicalOrder.isEmpty else { return }
        if let idx = canonicalOrder.firstIndex(of: currentSceneId) {
            progress = Double(idx + 1) / Double(canonicalOrder.count)
        } else {
            let currentOrder = currentScene?.order ?? 0
            let closestIdx = canonicalOrder.indices.last(where: {
                (sceneMap[canonicalOrder[$0]]?.order ?? 0) <= currentOrder
            }) ?? 0
            progress = Double(closestIdx + 1) / Double(canonicalOrder.count)
        }
    }

    private func isFinalCanonicalScene(_ id: String) -> Bool {
        canonicalOrder.last == id
    }

    private func triggerCompletion() {
        gameCompleted = true
        HapticManager.shared.success()
        markComplete()
    }

    private func persistProgress() {
        guard let sceneId = UUID(uuidString: currentSceneId),
              let scenarioId = scenarioId,
              let userIdStr = SupabaseManager.shared.currentUserId,
              let userId = UUID(uuidString: userIdStr) else { return }
        Task { @concurrent in
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
        Task { @concurrent in
            try? await practiceService.completeScenario(userId: userId, scenarioId: scenarioId)
        }
    }
}

// MARK: - Main Game View
struct PracticeGame: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: PracticeGameViewModel
    @State private var showGameComplete = false
    @State private var showIntroScreen = true
    @EnvironmentObject private var tabBarVisibility: TabBarVisibilityManager

    init(
        gameData: PracticeGameData = MockData.barWindow,
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
                // Top Navigation Bar
                HStack(spacing: 12) {
                    Button {
                        tabBarVisibility.showTabBar()
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22))
                            .foregroundColor(.wingmanBlack)
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
                                .fill(Color.wingmanBlack)
                                .frame(width: geometry.size.width * CGFloat(viewModel.progress), height: 10)
                                .animation(.easeInOut(duration: 0.25), value: viewModel.progress)
                        }
                    }
                    .frame(height: 10)

                    Spacer().frame(width: 15)
                }
                .padding(.top, 8)
                .padding(.leading, 20)
                .padding(.trailing, 44)
                .padding(.bottom, 12)

                if showIntroScreen {
                    GameIntroScreenView(
                        onLeftTap: {
                            tabBarVisibility.showTabBar()
                            dismiss()
                        },
                        onRightTap: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showIntroScreen = false
                            }
                        }
                    )
                } else if let scene = viewModel.currentScene {
                    GameSceneView(
                        scene: scene,
                        userName: viewModel.userName,
                        onTapContinue: { viewModel.goToNextScene() },
                        onTapRetry:    { viewModel.retryCurrentScene() },
                        onSelectOption: { option in viewModel.selectOption(option) },
                        onTapBack:     {
                            if viewModel.currentSceneId == viewModel.gameData.startingScreenId {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showIntroScreen = true
                                }
                            } else {
                                viewModel.goToPreviousScene()
                            }
                        }
                    )
                    .id(scene.id)
                }
            }
        }
        .navigationBarHidden(true)
        .enableInteractivePopGesture()
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            tabBarVisibility.hideTabBar()
        }
        .onDisappear {
            tabBarVisibility.showTabBar()
        }
        .onChange(of: viewModel.gameCompleted) { completed in
            if completed { showGameComplete = true }
        }
        .fullScreenCover(isPresented: $showGameComplete) {
            GameCompleteView {
                tabBarVisibility.showTabBar()
                dismiss()
            }
        }
    }
}

// MARK: - Game Intro Screen View
struct GameIntroScreenView: View {
    let onLeftTap: () -> Void
    let onRightTap: () -> Void
    private let dividerPosition: CGFloat = 0.4
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                HStack(spacing: 0) {
                    VStack {
                        Spacer()
                        Text("Back")
                            .font(.manropeMedium(size: 20))
                            .foregroundColor(Color(hex: "000000"))
                            .opacity(0.5)
                        Spacer()
                    }
                    .frame(width: geo.size.width * dividerPosition)
                    .contentShape(Rectangle())
                    .onTapGesture { onLeftTap() }

                    VStack {
                        Spacer()
                        Text("Forward")
                            .font(.manropeMedium(size: 20))
                            .foregroundColor(Color(hex: "000000"))
                            .opacity(0.5)
                        Spacer()
                    }
                    .frame(width: geo.size.width * (1 - dividerPosition))
                    .contentShape(Rectangle())
                    .onTapGesture { onRightTap() }
                }

                let topPadding: CGFloat = 20
                let bottomPadding: CGFloat = 40
                let paddedHeight = max(0, geo.size.height - (topPadding + bottomPadding))
                let centerYOffset = (topPadding - bottomPadding) / 2
                
                Rectangle()
                    .fill(Color.wingmanBlack.opacity(0.5))
                    .frame(width: 1, height: paddedHeight)
                    .position(
                        x: geo.size.width * dividerPosition,
                        y: geo.size.height / 2 + centerYOffset
                    )
                    .allowsHitTesting(false)
            }
        }
    }
}

// MARK: - Game Scene View
struct GameSceneView: View {
    let scene: GameScene
    let userName: String
    let onTapContinue: () -> Void
    let onTapRetry: () -> Void
    let onSelectOption: (GameOption) -> Void
    let onTapBack: () -> Void
    
    @State private var isVisible: Bool = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if scene.type == .options {
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: geometry.size.width / 2)
                            .contentShape(Rectangle())
                            .onTapGesture { onTapBack() }
                        Spacer()
                    }
                }
                
                VStack(spacing: 0) {
                    if scene.type != .options, let imageName = scene.imageName {
                        Image(imageName)
                            .resizable()
                            .scaledToFit()
                            .padding(.horizontal, 20)
                            .padding(.bottom,40)
                    }

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
                        DialogueContentView(scene: scene, userName: userName)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 40)
                            .scaleEffect(isVisible ? 1.0 : 0.85)
                            .opacity(isVisible ? 1.0 : 0.0)
                    }
                }
                
                if scene.type != .options {
                    HStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: geometry.size.width / 2)
                            .contentShape(Rectangle())
                            .onTapGesture { onTapBack() }
                        
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: geometry.size.width / 2)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if scene.type == .feedback { onTapRetry() }
                                else { onTapContinue() }
                            }
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                withAnimation(.easeOut(duration: 0.25)) { isVisible = true }
            }
        }
    }
}

// MARK: - Dialogue Content View
struct DialogueContentView: View {
    let scene: GameScene
    let userName: String

    private var displayName: String {
        switch scene.type {
        case .userDialogue:  return userName
        case .womanDialogue: return scene.characterName ?? "Her"
        case .feedback:      return "Feedback"
        default:             return ""
        }
    }

    private var actionText: String {
        scene.type == .feedback ? "Tap to retry" : "Tap to continue"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // FIXED: Reserve height for the name tag so the box doesn't jump
            ZStack {
                if !displayName.isEmpty {
                    Text(displayName)
                        .font(.manropeMedium(size: 18))
                        .foregroundColor(.wingmanBlack.opacity(0.6))
                        .frame(maxWidth: .infinity, alignment: scene.type == .womanDialogue ? .trailing : .leading)
                        .padding(.horizontal, 8)
                        .padding(.top,10)
                }
            }
            .frame(height: 25)

            VStack(alignment: .leading, spacing: 0) {
                // Min-height reserves the 2-line layout so 1- and 2-line scenes
                // are visually identical to before. Text is allowed to wrap to
                // 3+ lines on smaller devices and the box grows to fit.
                Text(scene.text)
                    .font(.manropeMedium(size: 14))
                    .foregroundColor(.wingmanBlack)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 25)
            }
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.wingmanBlack.opacity(0.1), lineWidth: 1)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.white))
                    .shadow(color: Color.wingmanBlack.opacity(0.06), radius: 5, x: 0, y: 2)
            )

            Text(actionText)
                .font(.manropeMedium(size: 14))
                .foregroundColor(.wingmanBlack.opacity(0.5))
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
                Button { onSelectOption(option) } label: {
                    Text(option.text)
                        .font(.manropeSemiBold(size: 16))
                        .foregroundColor(.wingmanBlack)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 15)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.wingmanBlack.opacity(0.1), lineWidth: 1)
                                .background(RoundedRectangle(cornerRadius: 5).fill(Color.white))
                                .shadow(color: Color.wingmanBlack.opacity(0.06), radius: 5, x: 0, y: 2)
                        )
                }
                .buttonStyle(.plain)
            }

            Text("Choose an option to continue")
                .font(.manropeMedium(size: 14))
                .foregroundColor(.wingmanBlack.opacity(0.4))
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
                    .foregroundColor(.wingmanBlack)

                Spacer()

                Button { onContinue() } label: {
                    Text("Continue")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.wingmanBlack)
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
    nonisolated static let barWindow = PracticeGameData(
        id: "a0000001-0000-0000-0000-000000000001",
        title: "Bar Window",
        startingScreenId: "screen_001",
        scenes: [
            GameScene(id: "screen_001", type: .context,
                      characterName: nil,
                      text: "After a long week of work you've decided to unwind and get a drink at the bar.",
                      imageName: "game_person_m", options: nil, order: 1,
                      defaultNextScreenId: "screen_002", retryTargetScreenId: nil),

            GameScene(id: "screen_002", type: .context,
                      characterName: nil,
                      text: "You enter the bar and see a girl standing by herself ordering a drink.",
                      imageName: "game_person_f", options: nil, order: 2,
                      defaultNextScreenId: "screen_003", retryTargetScreenId: nil),

            GameScene(id: "screen_003", type: .context,
                      characterName: nil,
                      text: "She glances over at you briefly, smiles, then faces back to the bar.",
                      imageName: "game_person_f", options: nil, order: 3,
                      defaultNextScreenId: "screen_004", retryTargetScreenId: nil),

            GameScene(id: "screen_004", type: .options,
                      characterName: nil, text: "", imageName: nil,
                      options: [
                          GameOption(id: "q1_a", text: "Wait and scout out the venue first",    nextSceneId: "screen_004_fail_a",  isCorrect: false, orderIndex: 0),
                          GameOption(id: "q1_b", text: "Try make eye contact again then go",    nextSceneId: "screen_004_fail_a",  isCorrect: false, orderIndex: 1),
                          GameOption(id: "q1_c", text: "Start walking towards her",             nextSceneId: "screen_005",         isCorrect: true,  orderIndex: 2),
                      ],
                      order: 4, defaultNextScreenId: nil, retryTargetScreenId: nil),

            GameScene(id: "screen_004_fail_a", type: .context,
                      characterName: nil,
                      text: "You wait a while but by then another man starts talking to her.",
                      imageName: "game_person_m", options: nil, order: 5,
                      defaultNextScreenId: "screen_004_fail_aa", retryTargetScreenId: nil),

            GameScene(id: "screen_004_fail_aa", type: .feedback,
                      characterName: nil,
                      text: "Night environments change quickly. Hesitation turns signals into missed chances.",
                      imageName: "game_person_m", options: nil, order: 6,
                      defaultNextScreenId: "screen_004",
                      retryTargetScreenId: "screen_004"),

            GameScene(id: "screen_005", type: .context,
                      characterName: nil,
                      text: "You walk over with relaxed energy. No hesitation. Arms swinging naturally.",
                      imageName: "game_person_m", options: nil, order: 7,
                      defaultNextScreenId: "screen_006", retryTargetScreenId: nil),

            GameScene(id: "screen_006", type: .context,
                      characterName: nil,
                      text: "You get closer and she's still facing the bar.",
                      imageName: "game_person_f", options: nil, order: 8,
                      defaultNextScreenId: "screen_007", retryTargetScreenId: nil),

            GameScene(id: "screen_007", type: .options,
                      characterName: nil, text: "", imageName: nil,
                      options: [
                          GameOption(id: "q2_a", text: "Stand behind her and wait for her to turn around",  nextSceneId: "screen_007_fail_a",  isCorrect: false, orderIndex: 0),
                          GameOption(id: "q2_b", text: "Stand beside her and open with a light comment",    nextSceneId: "screen_008",         isCorrect: true,  orderIndex: 1),
                          GameOption(id: "q2_c", text: "Tap her shoulder and offer to buy her a drink",     nextSceneId: "screen_007_fail_c",  isCorrect: false, orderIndex: 2),
                      ],
                      order: 9, defaultNextScreenId: nil, retryTargetScreenId: nil),

            GameScene(id: "screen_007_fail_a", type: .context,
                      characterName: nil,
                      text: "You stand a few feet away. Waiting. She picks up her drink, then she turns and leaves.",
                      imageName: "game_person_f", options: nil, order: 10,
                      defaultNextScreenId: "screen_007_fail_aa", retryTargetScreenId: nil),

            GameScene(id: "screen_007_fail_aa", type: .feedback,
                      characterName: nil,
                      text: "You need to create the interaction, not wait for it to happen to you.",
                      imageName: "game_person_m", options: nil, order: 11,
                      defaultNextScreenId: "screen_007",
                      retryTargetScreenId: "screen_007"),

            GameScene(id: "screen_007_fail_c", type: .context,
                      characterName: nil,
                      text: "She turns, startled. Declines your offer as she already has a drink.",
                      imageName: "game_person_f", options: nil, order: 12,
                      defaultNextScreenId: "screen_007_fail_cc", retryTargetScreenId: nil),

            GameScene(id: "screen_007_fail_cc", type: .feedback,
                      characterName: nil,
                      text: "Shoulder tap was invasive. Drink offer before rapport made it transactional.",
                      imageName: "game_person_m", options: nil, order: 13,
                      defaultNextScreenId: "screen_007",
                      retryTargetScreenId: "screen_007"),

            GameScene(id: "screen_008", type: .userDialogue,
                      characterName: nil,
                      text: "Let me guess, vodka lemonade?",
                      imageName: "game_person_m", options: nil, order: 14,
                      defaultNextScreenId: "screen_009", retryTargetScreenId: nil),

            GameScene(id: "screen_009", type: .womanDialogue,
                      characterName: "Sophie",
                      text: "Vodka soda, actually. Close though.",
                      imageName: "game_person_f", options: nil, order: 15,
                      defaultNextScreenId: "screen_010", retryTargetScreenId: nil),

            GameScene(id: "screen_010", type: .context,
                      characterName: nil,
                      text: "She's engaged and shifts to face you, smiling. Holding eye contact.",
                      imageName: "game_person_f", options: nil, order: 16,
                      defaultNextScreenId: "screen_011", retryTargetScreenId: nil),

            GameScene(id: "screen_011", type: .options,
                      characterName: nil, text: "", imageName: nil,
                      options: [
                          GameOption(id: "q3_a", text: "Ask to buy her next drink after she's done",                nextSceneId: "screen_011_fail_a",  isCorrect: false, orderIndex: 0),
                          GameOption(id: "q3_b", text: "Build on her answer then ask what brings her here tonight", nextSceneId: "screen_012",         isCorrect: true,  orderIndex: 1),
                          GameOption(id: "q3_c", text: "Ask her what she does for work",                           nextSceneId: "screen_011_fail_c",  isCorrect: false, orderIndex: 2),
                      ],
                      order: 17, defaultNextScreenId: nil, retryTargetScreenId: nil),

            GameScene(id: "screen_011_fail_a", type: .womanDialogue,
                      characterName: "Sophie",
                      text: "Umm... Maybe later, I still have this one.",
                      imageName: "game_person_f", options: nil, order: 18,
                      defaultNextScreenId: "screen_011_fail_aa", retryTargetScreenId: nil),

            GameScene(id: "screen_011_fail_aa", type: .feedback,
                      characterName: nil,
                      text: "Attraction isn't transactional. She was already engaged. You don't need to buy her a drink.",
                      imageName: "game_person_m", options: nil, order: 19,
                      defaultNextScreenId: "screen_011",
                      retryTargetScreenId: "screen_011"),

            GameScene(id: "screen_011_fail_c", type: .context,
                      characterName: nil,
                      text: "She responds with \"Marketing, what about you?\" but her energy is off.",
                      imageName: "game_person_f", options: nil, order: 20,
                      defaultNextScreenId: "screen_011_fail_cc", retryTargetScreenId: nil),

            GameScene(id: "screen_011_fail_cc", type: .feedback,
                      characterName: nil,
                      text: "Nightclubs are playful and spontaneous. Interview questions kill the vibe.",
                      imageName: "game_person_m", options: nil, order: 21,
                      defaultNextScreenId: "screen_011",
                      retryTargetScreenId: "screen_011"),

            GameScene(id: "screen_012", type: .userDialogue,
                      characterName: nil,
                      text: "Healthy choice. What brings you here tonight?",
                      imageName: "game_person_m", options: nil, order: 22,
                      defaultNextScreenId: "screen_013", retryTargetScreenId: nil),

            GameScene(id: "screen_013", type: .womanDialogue,
                      characterName: "Sophie",
                      text: "We're just celebrating our friend's birthday tonight...",
                      imageName: "game_person_f", options: nil, order: 23,
                      defaultNextScreenId: "screen_014", retryTargetScreenId: nil),

            GameScene(id: "screen_014", type: .userDialogue,
                      characterName: nil,
                      text: "I hope they won't be annoyed that I've stolen you away from them then.",
                      imageName: "game_person_m", options: nil, order: 24,
                      defaultNextScreenId: "screen_015", retryTargetScreenId: nil),

            GameScene(id: "screen_015", type: .womanDialogue,
                      characterName: "Sophie",
                      text: "Hahaha I'm sure they'll live.",
                      imageName: "game_person_f", options: nil, order: 25,
                      defaultNextScreenId: "screen_016", retryTargetScreenId: nil),

            GameScene(id: "screen_016", type: .context,
                      characterName: nil,
                      text: "You're still talking at the bar. She's laughing, leaning in close. The energy is good.",
                      imageName: "game_person_f", options: nil, order: 26,
                      defaultNextScreenId: "screen_017", retryTargetScreenId: nil),

            GameScene(id: "screen_017", type: .context,
                      characterName: nil,
                      text: "However the bar's getting busier now. People keep bumping into her.",
                      imageName: "game_person_f", options: nil, order: 27,
                      defaultNextScreenId: "screen_018", retryTargetScreenId: nil),

            GameScene(id: "screen_018", type: .options,
                      characterName: nil, text: "", imageName: nil,
                      options: [
                          GameOption(id: "q4_a", text: "Suggest moving to a quieter spot",     nextSceneId: "screen_019",        isCorrect: true,  orderIndex: 0),
                          GameOption(id: "q4_b", text: "Ignore it and keep talking",            nextSceneId: "screen_018_fail_b", isCorrect: false, orderIndex: 1),
                          GameOption(id: "q4_c", text: "Start pushing people away from her",   nextSceneId: "screen_018_fail_c", isCorrect: false, orderIndex: 2),
                      ],
                      order: 28, defaultNextScreenId: nil, retryTargetScreenId: nil),

            GameScene(id: "screen_018_fail_b", type: .context,
                      characterName: nil,
                      text: "You keep talking and someone bumps her. She spills her drink.",
                      imageName: "game_person_f", options: nil, order: 29,
                      defaultNextScreenId: "screen_018_fail_bb", retryTargetScreenId: nil),

            GameScene(id: "screen_018_fail_bb", type: .feedback,
                      characterName: nil,
                      text: "Notice discomfort and adjust. Ignoring it shows that you're oblivious.",
                      imageName: "game_person_m", options: nil, order: 30,
                      defaultNextScreenId: "screen_018",
                      retryTargetScreenId: "screen_018"),

            GameScene(id: "screen_018_fail_c", type: .context,
                      characterName: nil,
                      text: "Someone bumps her. You push them and Sophie steps back.",
                      imageName: "game_person_m", options: nil, order: 31,
                      defaultNextScreenId: "screen_018_fail_cc", retryTargetScreenId: nil),

            GameScene(id: "screen_018_fail_cc", type: .feedback,
                      characterName: nil,
                      text: "Overprotecting signals insecurity. She needs leadership, not a bodyguard.",
                      imageName: "game_person_m", options: nil, order: 32,
                      defaultNextScreenId: "screen_018",
                      retryTargetScreenId: "screen_018"),

            GameScene(id: "screen_019", type: .userDialogue,
                      characterName: nil,
                      text: "Hey it's getting busy here, let's go sit down over there.",
                      imageName: "game_person_m", options: nil, order: 33,
                      defaultNextScreenId: "screen_020", retryTargetScreenId: nil),

            GameScene(id: "screen_020", type: .context,
                      characterName: nil,
                      text: "Sophie agrees and you move to a quieter spot together alone.",
                      imageName: "game_person_f", options: nil, order: 34,
                      defaultNextScreenId: "screen_021", retryTargetScreenId: nil),

            GameScene(id: "screen_021", type: .context,
                      characterName: nil,
                      text: "The two of you continue your conversation sitting down, the vibe is intimate.",
                      imageName: "game_person_f", options: nil, order: 35,
                      defaultNextScreenId: "screen_022", retryTargetScreenId: nil),

            GameScene(id: "screen_022", type: .context,
                      characterName: nil,
                      text: "However you see one of her friends approaching and hovering nearby.",
                      imageName: "game_person_f", options: nil, order: 36,
                      defaultNextScreenId: "screen_023", retryTargetScreenId: nil),

            GameScene(id: "screen_023", type: .options,
                      characterName: nil, text: "", imageName: nil,
                      options: [
                          GameOption(id: "q5_a", text: "Smile at the friend and greet her",         nextSceneId: "screen_024",        isCorrect: true,  orderIndex: 0),
                          GameOption(id: "q5_b", text: "Ignore her and keep talking to Sophie",      nextSceneId: "screen_023_fail_b", isCorrect: false, orderIndex: 1),
                      ],
                      order: 37, defaultNextScreenId: nil, retryTargetScreenId: nil),

            GameScene(id: "screen_023_fail_b", type: .context,
                      characterName: nil,
                      text: "You keep talking and her friend comes and pulls Sophie away.",
                      imageName: "game_person_f", options: nil, order: 38,
                      defaultNextScreenId: "screen_023_fail_bb", retryTargetScreenId: nil),

            GameScene(id: "screen_023_fail_bb", type: .feedback,
                      characterName: nil,
                      text: "Inclusion reduces social tension and preserves control. Acknowledge her friends.",
                      imageName: "game_person_m", options: nil, order: 39,
                      defaultNextScreenId: "screen_023",
                      retryTargetScreenId: "screen_023"),

            GameScene(id: "screen_024", type: .userDialogue,
                      characterName: nil,
                      text: "Hey, Happy Birthday, how are you?",
                      imageName: "game_person_m", options: nil, order: 40,
                      defaultNextScreenId: "screen_025", retryTargetScreenId: nil),

            GameScene(id: "screen_025", type: .context,
                      characterName: nil,
                      text: "Her friend laughs and answers your question.",
                      imageName: "game_person_f", options: nil, order: 41,
                      defaultNextScreenId: "screen_026", retryTargetScreenId: nil),

            GameScene(id: "screen_026", type: .context,
                      characterName: nil,
                      text: "However, she informs Sophie that their Uber is here and they have to leave.",
                      imageName: "game_person_f", options: nil, order: 42,
                      defaultNextScreenId: "screen_027", retryTargetScreenId: nil),

            GameScene(id: "screen_027", type: .context,
                      characterName: nil,
                      text: "Sophie gets up to leave with her friend.",
                      imageName: "game_person_f", options: nil, order: 43,
                      defaultNextScreenId: "screen_028", retryTargetScreenId: nil),

            GameScene(id: "screen_028", type: .options,
                      characterName: nil, text: "", imageName: nil,
                      options: [
                          GameOption(id: "q6_a", text: "Say \"It was nice to meet you\" and leave it", nextSceneId: "screen_028_fail_a", isCorrect: false, orderIndex: 0),
                          GameOption(id: "q6_b", text: "Ask for her details before she leaves",        nextSceneId: "screen_029",        isCorrect: true,  orderIndex: 1),
                      ],
                      order: 44, defaultNextScreenId: nil, retryTargetScreenId: nil),

            GameScene(id: "screen_028_fail_a", type: .userDialogue,
                      characterName: nil,
                      text: "Well it was nice to meet you. Goodbye Sophie.",
                      imageName: "game_person_m", options: nil, order: 45,
                      defaultNextScreenId: "screen_028_fail_aa", retryTargetScreenId: nil),

            GameScene(id: "screen_028_fail_aa", type: .feedback,
                      characterName: nil,
                      text: "She was engaged and receptive. But you never closed, the story ends there.",
                      imageName: "game_person_m", options: nil, order: 46,
                      defaultNextScreenId: "screen_028",
                      retryTargetScreenId: "screen_028"),

            GameScene(id: "screen_029", type: .userDialogue,
                      characterName: nil,
                      text: "Hey before you leave add my Instagram.",
                      imageName: "game_person_m", options: nil, order: 47,
                      defaultNextScreenId: "screen_030", retryTargetScreenId: nil),

            GameScene(id: "screen_030", type: .context,
                      characterName: nil,
                      text: "Sophie pulls out her phone and adds you happily and leaves after. Success.",
                      imageName: "game_person_f", options: nil, order: 48,
                      defaultNextScreenId: "screen_031", retryTargetScreenId: nil),

            GameScene(id: "screen_031", type: .context,
                      characterName: nil,
                      text: "You review your interaction with Sophie tonight.",
                      imageName: "game_person_m", options: nil, order: 49,
                      defaultNextScreenId: "screen_032", retryTargetScreenId: nil),

            GameScene(id: "screen_032", type: .context,
                      characterName: nil,
                      text: "You opened naturally and kept it playful instead of transactional.",
                      imageName: "game_person_m", options: nil, order: 50,
                      defaultNextScreenId: "screen_033", retryTargetScreenId: nil),

            GameScene(id: "screen_033", type: .context,
                      characterName: nil,
                      text: "You read the environment well by moving from the bar and also greeting her friend.",
                      imageName: "game_person_m", options: nil, order: 51,
                      defaultNextScreenId: "screen_034", retryTargetScreenId: nil),

            GameScene(id: "screen_034", type: .context,
                      characterName: nil,
                      text: "And you had an enjoyable fun conversation. Well done.",
                      imageName: "game_person_m", options: nil, order: 52,
                      defaultNextScreenId: "complete",
                      retryTargetScreenId: nil),
        ]
    )
}

// MARK: - Preview
#Preview {
    NavigationView {
        PracticeGame()
            .environmentObject(TabBarVisibilityManager())
            .environmentObject(CoursesRouter())
    }
}
