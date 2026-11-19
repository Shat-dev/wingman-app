//
//  DuoRegularWidthRenderTests.swift
//  WingmanTests
//
//  Screens in a regular-width window — the iPhone Duo's inner display, open,
//  portrait and landscape — where `readableColumn()` keeps the phone layout in
//  a centred column instead of stretching it edge to edge.
//
//  Pictures for review, attached as "6N-duo-regular-<screen>-<width>x<height>".
//  The sizes are stand-ins until the iPhone Duo simulator can measure the real
//  ones. The size class is set explicitly, as the inner display would.
//

import RevenueCat
import SwiftUI
import XCTest
@testable import Wingman

@MainActor
final class DuoRegularWidthRenderTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Analytics.recorderForTesting = { _ in }
    }

    override func tearDown() {
        Analytics.recorderForTesting = nil
        super.tearDown()
    }

    static let sizes = [CGSize(width: 800, height: 1000), CGSize(width: 1000, height: 800)]

    private func tag(_ size: CGSize) -> String { "\(Int(size.width))x\(Int(size.height))" }

    private func draw(_ view: some View, size: CGSize, name: String, wait: TimeInterval = 1.5) throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        let host = UIHostingController(
            rootView: view
                .environment(\.horizontalSizeClass, .regular)
                .background(Color.white)
                .readsWindowSize()
        )
        host.safeAreaRegions = []
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(wait))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            host.view.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
        window.isHidden = true
        window.rootViewController = nil

        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func package(
        _ identifier: String, _ type: PackageType, id: String, price: Decimal, priceString: String,
        productType: StoreProduct.ProductType, period: SubscriptionPeriod?
    ) -> Package {
        let product = TestStoreProduct(
            localizedTitle: identifier, price: price, currencyCode: "USD", localizedPriceString: priceString,
            productIdentifier: id, productType: productType, localizedDescription: identifier,
            subscriptionGroupIdentifier: period == nil ? nil : "wingman", subscriptionPeriod: period,
            locale: Locale(identifier: "en_US")
        )
        return Package(identifier: identifier, packageType: type, storeProduct: product.toStoreProduct(),
                       offeringIdentifier: "fixture", webCheckoutUrl: nil)
    }

    func testScreensInARegularWidthWindow() throws {
        let yearly = package("yearly", .annual, id: Constants.YEARLY_PRODUCT_ID, price: 55.99, priceString: "$55.99",
                             productType: .autoRenewableSubscription, period: SubscriptionPeriod(value: 1, unit: .year))
        let monthly = package("monthly", .monthly, id: Constants.MONTHLY_PRODUCT_ID, price: 14.99, priceString: "$14.99",
                              productType: .autoRenewableSubscription, period: SubscriptionPeriod(value: 1, unit: .month))
        let lifetime = package("lifetime", .lifetime, id: Constants.LIFETIME_PRODUCT_ID, price: 55.99,
                               priceString: "$55.99", productType: .nonConsumable, period: nil)
        let discounted = package(Constants.ONE_TIME_OFFER_LIFETIME_PACKAGE_ID, .custom,
                                 id: Constants.LIFETIME_DISCOUNT_PRODUCT_ID, price: 27.99, priceString: "$27.99",
                                 productType: .nonConsumable, period: nil)
        let question = try XCTUnwrap(extendedOnboardingSteps.first { $0.type == .question })
        let statistic = try XCTUnwrap(StatisticContent.for(questionKey: "last_approach", ageGroup: "25-34"))

        for size in Self.sizes {
            let offering = Offering(identifier: "fixture", serverDescription: "fixture",
                                    availablePackages: [yearly, monthly], webCheckoutUrl: nil)
            try draw(
                PaywallView(isDismissible: true, onDismiss: {}, source: .featureGate,
                            viewModel: PaywallViewModel(fixtureOffering: offering))
                    .environmentObject(AuthManager()),
                size: size, name: "60-duo-regular-paywall-\(tag(size))", wait: 3.6
            )
            try draw(
                OneTimeOfferView(viewModel: OneTimeOfferViewModel(fixturePackage: discounted, regularLifetime: lifetime),
                                 onFinish: {})
                    .environmentObject(AuthManager()),
                size: size, name: "61-duo-regular-offer-\(tag(size))", wait: 3.6
            )
            try draw(QuestionScreen(step: question, initialSelection: [], onNext: { _ in }),
                     size: size, name: "62-duo-regular-question-\(tag(size))")
            try draw(StatisticScreen(statistic: statistic, onContinue: {}),
                     size: size, name: "63-duo-regular-statistic-\(tag(size))", wait: 2.5)
            try draw(LandingView().environmentObject(AuthManager()),
                     size: size, name: "64-duo-regular-landing-\(tag(size))")
            try draw(
                QuizQuestionView(
                    state: QuizQuestionState(
                        number: 2, text: "Which are key for confident body language?",
                        options: ["Eye contact", "Good posture", "Fidgeting", "Speaking clearly"],
                        isMultipleSelect: true, selectedIndices: [0, 2], correctIndices: [0, 1, 3],
                        hasCheckedAnswer: true, isAnswerCorrect: false,
                        explanation: "Confident body language includes eye contact, good posture and speaking clearly."
                    ),
                    onSelectOption: { _ in }, onCheckAnswer: {}, onNext: {}
                ),
                size: size, name: "65-duo-regular-quiz-\(tag(size))"
            )
            try draw(
                CompletionScreen(
                    title: "Lesson complete.", expectedSourceId: "lesson_1_1",
                    previewAward: XPStore.Award(source: .lesson, sourceId: "lesson_1_1", amount: 40, totalAfter: 335,
                                                base: 20, fromCorrect: 15, bonus: 5, correctCount: 3),
                    onContinue: {}, detail: { EmptyView() }
                ),
                size: size, name: "66-duo-regular-completion-\(tag(size))", wait: 6.0
            )
            try draw(AuthView(mode: .signup).environmentObject(AuthManager()),
                     size: size, name: "67-duo-regular-auth-\(tag(size))")
        }
    }
}
