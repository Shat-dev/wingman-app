//
//  DuoBaselineRenderTests.swift
//  WingmanTests
//
//  Regression baseline for the iPhone Duo work (docs/iphone-duo-loop.md).
//
//  Every screen is drawn at the size of the simulator's own screen, with the
//  simulator's real safe area. Running the suite on an iPhone SE, a 17, a 17e
//  and a 17 Pro Max therefore draws each screen exactly as that phone shows
//  it, including the `UIScreen.isSmallPhone` branch the phone really takes.
//
//  Attachments are named "NN-duo-<screen>-<layout>" so that
//  `scripts/screenshots.py export` picks them up. "en" is the English layout,
//  "tr" the translated layout (a German bundle with no strings, so the text
//  stays English and only the layout path changes). Export a run before a
//  layout change and a run after it; on every current iPhone the pictures
//  must be identical.
//
//  Fixtures only: no network calls are awaited, and analytics are recorded,
//  never sent.
//

import RevenueCat
import SwiftUI
import XCTest
@testable import Wingman

@MainActor
final class DuoBaselineRenderTests: XCTestCase {

    private var temporaryRoot: URL?

    override func setUp() {
        super.setUp()
        Analytics.recorderForTesting = { _ in }
    }

    override func tearDown() {
        Analytics.recorderForTesting = nil
        L10n.sourceOverrideForTesting = nil
        if let temporaryRoot {
            try? FileManager.default.removeItem(at: temporaryRoot)
        }
        temporaryRoot = nil
        super.tearDown()
    }

    // MARK: - Layouts

    private enum Layout: String, CaseIterable {
        case en
        case tr
    }

    private func use(_ layout: Layout) throws {
        L10n.sourceOverrideForTesting = nil
        if let temporaryRoot {
            try? FileManager.default.removeItem(at: temporaryRoot)
            self.temporaryRoot = nil
        }
        guard layout == .tr else { return }
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("duo-tests-\(UUID().uuidString)", isDirectory: true)
        let lproj = root.appendingPathComponent("de.lproj", isDirectory: true)
        try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: [String: String](), format: .binary, options: 0)
        try data.write(to: lproj.appendingPathComponent("\(L10n.contentTable).strings"))
        temporaryRoot = root
        L10n.sourceOverrideForTesting = .bundle(try XCTUnwrap(Bundle(url: lproj)))
    }

    // MARK: - Drawing

    /// Draws `view` full screen at the simulator's screen size and attaches it.
    @discardableResult
    private func draw(
        _ view: some View, name: String, wait: TimeInterval = 1.5, afterAppearing: () -> Void = {}
    ) throws -> UIImage {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let size = scene.screen.bounds.size
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        // `.readsWindowSize()` as WingmanApp applies it at the root, so the
        // screens get the same `\.windowSize` they get in the app.
        let host = UIHostingController(rootView: view.background(Color.white).readsWindowSize())
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(wait))
        afterAppearing()
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        window.isHidden = true
        window.rootViewController = nil

        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return image
    }

    private func forEachLayout(_ body: (Layout) throws -> Void) throws {
        for layout in Layout.allCases {
            try use(layout)
            try body(layout)
        }
    }

    // MARK: - Store fixtures (as in PaywallRenderTests)

    private func package(
        _ identifier: String, _ type: PackageType, id: String, price: Decimal, priceString: String,
        productType: StoreProduct.ProductType, period: SubscriptionPeriod?
    ) -> Package {
        let product = TestStoreProduct(
            localizedTitle: identifier,
            price: price,
            currencyCode: "USD",
            localizedPriceString: priceString,
            productIdentifier: id,
            productType: productType,
            localizedDescription: identifier,
            subscriptionGroupIdentifier: period == nil ? nil : "wingman",
            subscriptionPeriod: period,
            locale: Locale(identifier: "en_US")
        )
        return Package(
            identifier: identifier,
            packageType: type,
            storeProduct: product.toStoreProduct(),
            offeringIdentifier: "fixture",
            webCheckoutUrl: nil
        )
    }

    private var lifetimePackage: Package {
        package(
            "lifetime", .lifetime, id: Constants.LIFETIME_PRODUCT_ID, price: 55.99, priceString: "$55.99",
            productType: .nonConsumable, period: nil
        )
    }

    private var discountedLifetimePackage: Package {
        package(
            Constants.ONE_TIME_OFFER_LIFETIME_PACKAGE_ID, .custom, id: Constants.LIFETIME_DISCOUNT_PRODUCT_ID,
            price: 27.99, priceString: "$27.99", productType: .nonConsumable, period: nil
        )
    }

    private func offering(withLifetime: Bool) -> Offering {
        var packages = [
            package(
                "yearly", .annual, id: Constants.YEARLY_PRODUCT_ID, price: 55.99, priceString: "$55.99",
                productType: .autoRenewableSubscription, period: SubscriptionPeriod(value: 1, unit: .year)
            ),
            package(
                "monthly", .monthly, id: Constants.MONTHLY_PRODUCT_ID, price: 14.99, priceString: "$14.99",
                productType: .autoRenewableSubscription, period: SubscriptionPeriod(value: 1, unit: .month)
            )
        ]
        if withLifetime {
            packages.append(lifetimePackage)
        }
        return Offering(
            identifier: "fixture",
            serverDescription: "Render test fixture",
            availablePackages: packages,
            webCheckoutUrl: nil
        )
    }

    // MARK: - The running app's own window

    /// The test host is the real app, so its key window shows the real
    /// `RootView` (Landing, on a fresh throwaway simulator). This is the only
    /// render that goes through `WingmanApp`'s root modifiers, so it is what
    /// proves a change at the root leaves the app pixel-identical.
    func testHostAppRootWindow() throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        // Past the splash hand-off.
        RunLoop.main.run(until: Date().addingTimeInterval(6.0))
        let window = try XCTUnwrap(scene.windows.first { $0.isKeyWindow } ?? scene.windows.first)
        let size = window.bounds.size
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            window.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        let attachment = XCTAttachment(image: image)
        attachment.name = "00-duo-hostapp-root"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Onboarding

    func testOnboardingScreens() throws {
        let question = try XCTUnwrap(extendedOnboardingSteps.first { $0.type == .question })
        let statistic = try XCTUnwrap(StatisticContent.for(questionKey: "last_approach", ageGroup: "25-34"))
        try forEachLayout { layout in
            try draw(LandingView().environmentObject(AuthManager()), name: "01-duo-landing-\(layout.rawValue)")
            try draw(
                QuestionScreen(step: question, initialSelection: [], onNext: { _ in }),
                name: "02-duo-question-\(layout.rawValue)"
            )
            try draw(
                StatisticScreen(statistic: statistic, onContinue: {}),
                name: "03-duo-statistic-\(layout.rawValue)", wait: 2.5
            )
            try draw(GrowthProjectionScreen(onContinue: {}), name: "04-duo-growth-\(layout.rawValue)", wait: 3.5)
            try draw(SocialProofScreen(onContinue: {}), name: "05-duo-socialproof-\(layout.rawValue)", wait: 4.0)
            try draw(
                CommitmentPactView(earlyReleases: 0).environmentObject(AuthManager()),
                name: "06-duo-pact-\(layout.rawValue)"
            )
        }
    }

    // MARK: - Paywall and one-time offer

    func testPaywallAndOffer() throws {
        try forEachLayout { layout in
            for (index, withLifetime) in [false, true].enumerated() {
                let viewModel = PaywallViewModel(fixtureOffering: offering(withLifetime: withLifetime))
                let view = PaywallView(isDismissible: true, onDismiss: {}, source: .featureGate, viewModel: viewModel)
                    .environmentObject(AuthManager())
                // Past the 3 s after which the close button fades in.
                try draw(
                    view, name: "\(String(format: "%02d", 7 + index))-duo-paywall-\(withLifetime ? "lifetime" : "yearly")-\(layout.rawValue)",
                    wait: 3.6
                )
            }
            let offer = OneTimeOfferViewModel(fixturePackage: discountedLifetimePackage, regularLifetime: lifetimePackage)
            try draw(
                OneTimeOfferView(viewModel: offer, onFinish: {}).environmentObject(AuthManager()),
                name: "09-duo-offer-\(layout.rawValue)", wait: 3.6
            )
        }
    }

    // MARK: - Auth

    func testAuthScreens() throws {
        try forEachLayout { layout in
            try draw(
                AuthView(mode: .signup).environmentObject(AuthManager()),
                name: "10-duo-auth-signup-\(layout.rawValue)"
            )
            try draw(
                AuthView(mode: .signup, context: .requiredAfterPaywall).environmentObject(AuthManager()),
                name: "11-duo-auth-afterpaywall-\(layout.rawValue)"
            )
        }
    }

    // MARK: - Quiz and completion

    private func quizState(checked: Bool) -> QuizQuestionState {
        QuizQuestionState(
            number: 2,
            text: "Which are key for confident body language?",
            options: ["Eye contact", "Good posture", "Fidgeting", "Speaking clearly"],
            isMultipleSelect: true,
            selectedIndices: checked ? [0, 2] : [],
            correctIndices: [0, 1, 3],
            hasCheckedAnswer: checked,
            isAnswerCorrect: false,
            explanation: "Confident body language includes eye contact, good posture and speaking clearly."
        )
    }

    func testQuizAndCompletion() throws {
        try forEachLayout { layout in
            try draw(
                QuizQuestionView(state: quizState(checked: false), onSelectOption: { _ in }, onCheckAnswer: {}, onNext: {}),
                name: "12-duo-quiz-unanswered-\(layout.rawValue)"
            )
            try draw(
                QuizQuestionView(state: quizState(checked: true), onSelectOption: { _ in }, onCheckAnswer: {}, onNext: {}),
                name: "13-duo-quiz-checked-\(layout.rawValue)"
            )
            try draw(
                CompletionScreen(
                    title: "Lesson complete.",
                    expectedSourceId: "lesson_1_1",
                    previewAward: XPStore.Award(
                        source: .lesson, sourceId: "lesson_1_1", amount: 40, totalAfter: 335,
                        base: 20, fromCorrect: 15, bonus: 5, correctCount: 3
                    ),
                    onContinue: {},
                    detail: { EmptyView() }
                ),
                name: "14-duo-completion-\(layout.rawValue)", wait: 6.0
            )
        }
    }

    // MARK: - Profile sheets and tab bar

    func testSheetsAndTabBar() throws {
        try forEachLayout { layout in
            try draw(
                EditProfileSheet(currentName: "Alex", onSave: { _ in }),
                name: "15-duo-editprofile-\(layout.rawValue)"
            )
            try draw(
                DailyReadingGoalSheet(currentGoal: 5, onSave: { _ in }),
                name: "16-duo-readinggoal-\(layout.rawValue)"
            )
            // As MainTabView places it: bottom of a ZStack inside the safe
            // area; only the bar's own background runs under the home
            // indicator.
            try draw(
                ZStack(alignment: .bottom) {
                    Color.white
                    CustomTabBar(selectedTab: .constant(1))
                },
                name: "17-duo-tabbar-\(layout.rawValue)"
            )
        }
    }
}
