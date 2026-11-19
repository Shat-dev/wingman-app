//
//  DuoShortWindowRenderTests.swift
//  WingmanTests
//
//  The paywall and the one-time offer in windows shorter than any current
//  iPhone — the iPhone Duo's outer display, a folded half, a short split-screen
//  pane (docs/iphone-duo-audit.md, B2/B3). Their purchase controls must stay on
//  screen: the button, the disclosure, and Terms / Restore / Privacy along the
//  bottom.
//
//  These are new pictures for review, not a regression baseline: they are
//  attached as "5N-duo-short-<screen>-<width>x<height>" and the tests check
//  that the bottom strip, where the footer links sit, has ink in it.
//
//  The sizes are stand-ins until the iPhone Duo simulator can measure the
//  real ones.
//

import RevenueCat
import SwiftUI
import XCTest
@testable import Wingman

@MainActor
final class DuoShortWindowRenderTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Analytics.recorderForTesting = { _ in }
    }

    override func tearDown() {
        Analytics.recorderForTesting = nil
        super.tearDown()
    }

    static let sizes = [CGSize(width: 700, height: 420), CGSize(width: 600, height: 400), CGSize(width: 420, height: 380)]

    private func tag(_ size: CGSize) -> String { "\(Int(size.width))x\(Int(size.height))" }

    @discardableResult
    private func draw(_ view: some View, size: CGSize, name: String, wait: TimeInterval = 3.6) throws -> UIImage {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        let host = UIHostingController(rootView: view.background(Color.white).readsWindowSize())
        host.safeAreaRegions = []
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(wait))

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

    /// Share of pixels in `rect` (points) that are not near-white.
    private func inkShare(of image: UIImage, in rect: CGRect) throws -> Double {
        let cgImage = try XCTUnwrap(image.cgImage)
        let scale = CGFloat(cgImage.width) / image.size.width
        let pixelRect = CGRect(x: rect.minX * scale, y: rect.minY * scale, width: rect.width * scale, height: rect.height * scale).integral
        let cropped = try XCTUnwrap(cgImage.cropping(to: pixelRect))
        let width = cropped.width, height = cropped.height
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(
            data: &bytes, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: width, height: height))
        var ink = 0
        for pixel in stride(from: 0, to: bytes.count, by: 4) where bytes[pixel] < 215 || bytes[pixel + 1] < 215 || bytes[pixel + 2] < 215 {
            ink += 1
        }
        return Double(ink) / Double(width * height)
    }

    /// The footer links (Privacy, Restore, Terms) are the last row: some ink
    /// must be in the bottom 34pt.
    private func assertFooterDrawn(_ image: UIImage, _ size: CGSize, _ name: String) throws {
        XCTAssertGreaterThan(
            try inkShare(of: image, in: CGRect(x: 20, y: size.height - 34, width: size.width - 40, height: 30)),
            0.004, "\(name): nothing drawn where the footer links belong"
        )
    }

    // MARK: - Fixtures (as in PaywallRenderTests)

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
        return Package(
            identifier: identifier, packageType: type, storeProduct: product.toStoreProduct(),
            offeringIdentifier: "fixture", webCheckoutUrl: nil
        )
    }

    private var lifetimePackage: Package {
        package("lifetime", .lifetime, id: Constants.LIFETIME_PRODUCT_ID, price: 55.99, priceString: "$55.99",
                productType: .nonConsumable, period: nil)
    }

    private func offering(withLifetime: Bool) -> Offering {
        var packages = [
            package("yearly", .annual, id: Constants.YEARLY_PRODUCT_ID, price: 55.99, priceString: "$55.99",
                    productType: .autoRenewableSubscription, period: SubscriptionPeriod(value: 1, unit: .year)),
            package("monthly", .monthly, id: Constants.MONTHLY_PRODUCT_ID, price: 14.99, priceString: "$14.99",
                    productType: .autoRenewableSubscription, period: SubscriptionPeriod(value: 1, unit: .month))
        ]
        if withLifetime { packages.append(lifetimePackage) }
        return Offering(identifier: "fixture", serverDescription: "Render test fixture",
                        availablePackages: packages, webCheckoutUrl: nil)
    }

    // MARK: - Tests

    func testPaywallKeepsItsPurchaseControlsOnAShortWindow() throws {
        for size in Self.sizes {
            for withLifetime in [false, true] {
                let viewModel = PaywallViewModel(fixtureOffering: offering(withLifetime: withLifetime))
                let view = PaywallView(isDismissible: true, onDismiss: {}, source: .featureGate, viewModel: viewModel)
                    .environmentObject(AuthManager())
                let name = "5\(withLifetime ? 1 : 0)-duo-short-paywall-\(withLifetime ? "lifetime" : "yearly")-\(tag(size))"
                try assertFooterDrawn(try draw(view, size: size, name: name), size, name)
            }
        }
    }

    /// Screens whose English layout does not fit a short window and now
    /// scrolls there (S3). Pictures for review; what matters is that nothing
    /// is cut off without a way to scroll to it. The loading screen is not
    /// drawn: showing it writes to Supabase.
    func testScreensThatScrollOnAShortWindow() throws {
        let statistic = try XCTUnwrap(StatisticContent.for(questionKey: "last_approach", ageGroup: "25-34"))
        for size in Self.sizes {
            try draw(StatisticScreen(statistic: statistic, onContinue: {}), size: size,
                     name: "53-duo-short-statistic-\(tag(size))", wait: 2.5)
            try draw(GrowthProjectionScreen(onContinue: {}), size: size,
                     name: "54-duo-short-growth-\(tag(size))", wait: 3.5)
            try draw(CommitmentPactView(earlyReleases: 0).environmentObject(AuthManager()), size: size,
                     name: "55-duo-short-pact-\(tag(size))", wait: 1.5)
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
                size: size, name: "56-duo-short-completion-\(tag(size))", wait: 6.0
            )
            try draw(AuthView(mode: .signup, context: .requiredAfterPaywall).environmentObject(AuthManager()),
                     size: size, name: "57-duo-short-auth-afterpaywall-\(tag(size))", wait: 1.5)
            try draw(
                QuizQuestionView(
                    state: QuizQuestionState(
                        number: 2,
                        text: "Which are key for confident body language?",
                        options: ["Eye contact", "Good posture", "Fidgeting", "Speaking clearly"],
                        isMultipleSelect: true,
                        selectedIndices: [0, 2],
                        correctIndices: [0, 1, 3],
                        hasCheckedAnswer: true,
                        isAnswerCorrect: false,
                        explanation: "Confident body language includes eye contact, good posture and speaking clearly."
                    ),
                    onSelectOption: { _ in }, onCheckAnswer: {}, onNext: {}
                ),
                size: size, name: "58-duo-short-quiz-checked-\(tag(size))", wait: 1.5
            )
        }
    }

    func testOneTimeOfferKeepsItsPurchaseControlsOnAShortWindow() throws {
        for size in Self.sizes {
            let discounted = package(
                Constants.ONE_TIME_OFFER_LIFETIME_PACKAGE_ID, .custom, id: Constants.LIFETIME_DISCOUNT_PRODUCT_ID,
                price: 27.99, priceString: "$27.99", productType: .nonConsumable, period: nil
            )
            let offer = OneTimeOfferViewModel(fixturePackage: discounted, regularLifetime: lifetimePackage)
            let view = OneTimeOfferView(viewModel: offer, onFinish: {}).environmentObject(AuthManager())
            let name = "52-duo-short-offer-\(tag(size))"
            try assertFooterDrawn(try draw(view, size: size, name: name), size, name)
        }
    }
}
