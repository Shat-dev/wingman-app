//
//  PaywallRenderTests.swift
//  WingmanTests
//
//  Draws the whole paywall and the one-time offer in a test window at real
//  phone sizes, with and without the lifetime plan.
//
//  A Debug build loads no products, so the paywall never gets past "Can't
//  load pricing" on a simulator. These tests hand the view models fixture
//  packages instead (RevenueCat's own test products), which is the only way
//  to see the plan rows without a Release build and a real App Store product.
//
//  What they pin down:
//
//    * Lifetime in the offering: the paywall sells lifetime and monthly,
//      lifetime selected. Yearly is hidden.
//    * No lifetime in the offering: yearly and monthly, yearly selected.
//      This is the paywall as it ships today, and the fallback.
//    * The one-time offer for lifetime computes its percentage from the two
//      lifetime prices.
//
//  Renders are attached under stable names ("paywall-<plans>-<width>x
//  <height>", "offer-<kind>-<width>x<height>") so a run before a layout
//  change can be compared with a run after it.
//
//  Prices are the US prices set in App Store Connect on 2026-11-17: lifetime
//  at the yearly price, the discounted lifetime at the yearly offer price.
//

import RevenueCat
import SwiftUI
import XCTest
@testable import Wingman

@MainActor
final class PaywallRenderTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // The paywall reports `paywall_viewed` when it appears. Recorded
        // here, never sent.
        Analytics.recorderForTesting = { _ in }
    }

    override func tearDown() {
        Analytics.recorderForTesting = nil
        super.tearDown()
    }

    // MARK: - Fixture

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

    // MARK: - Drawing

    /// A phone's screen and the safe area the paywall is laid out inside.
    private struct Phone {
        let name: String
        let size: CGSize
        let top: CGFloat
        let bottom: CGFloat
    }

    private static let phones = [
        Phone(name: "se", size: CGSize(width: 375, height: 667), top: 20, bottom: 0),
        Phone(name: "17pro", size: CGSize(width: 402, height: 874), top: 62, bottom: 34)
    ]

    private func drawPaywall(
        _ viewModel: PaywallViewModel, on phone: Phone, name: String, select plan: SubscriptionPlan? = nil
    ) throws -> UIImage {
        let view = PaywallView(
            isDismissible: true,
            onDismiss: {},
            source: .featureGate,
            viewModel: viewModel
        )
        .environmentObject(AuthManager())
        return try draw(view, on: phone, name: name) {
            if let plan { viewModel.selectPlan(plan) }
        }
    }

    private func draw(
        _ content: some View, on phone: Phone, name: String, afterAppearing: () -> Void = {}
    ) throws -> UIImage {
        let view = content
            .padding(.top, phone.top)
            .padding(.bottom, phone.bottom)
            .background(Color.white)

        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: phone.size)
        let host = UIHostingController(rootView: view)
        host.safeAreaRegions = []
        window.rootViewController = host
        window.isHidden = false
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        // Past the 3 s after which the close button fades in.
        RunLoop.main.run(until: Date().addingTimeInterval(3.6))
        afterAppearing()
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let image = UIGraphicsImageRenderer(size: phone.size, format: format).image { _ in
            host.view.drawHierarchy(in: CGRect(origin: .zero, size: phone.size), afterScreenUpdates: true)
        }
        window.isHidden = true
        window.rootViewController = nil

        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        return image
    }

    private func tag(_ phone: Phone) -> String {
        "\(Int(phone.size.width))x\(Int(phone.size.height))"
    }

    // MARK: - Paywall

    /// No lifetime package: yearly and monthly, yearly selected. The paywall
    /// as it ships today, and what it falls back to when lifetime is taken
    /// out of the offering.
    func testWithoutLifetimeThePaywallIsYearlyAndMonthly() throws {
        for phone in Self.phones {
            let viewModel = PaywallViewModel(fixtureOffering: offering(withLifetime: false))
            XCTAssertNil(viewModel.lifetimePackage)
            XCTAssertEqual(viewModel.availablePlans, [.yearly, .monthly])
            XCTAssertEqual(viewModel.defaultPlan, .yearly)

            let image = try drawPaywall(viewModel, on: phone, name: "paywall-yearly-monthly-\(tag(phone))")
            XCTAssertEqual(image.size, phone.size)
            XCTAssertEqual(viewModel.selectedPlan, .yearly)
            XCTAssertEqual(viewModel.currentPackage?.packageType, .annual)
        }
    }

    /// A lifetime package in the offering: lifetime takes yearly's place and
    /// is the selected plan. The yearly package is still in the offering,
    /// only not shown.
    func testWithLifetimeThePaywallIsLifetimeAndMonthly() throws {
        for phone in Self.phones {
            let viewModel = PaywallViewModel(fixtureOffering: offering(withLifetime: true))
            XCTAssertNotNil(viewModel.yearlyPackage, "yearly stays in the offering as the fallback")
            XCTAssertEqual(viewModel.availablePlans, [.lifetime, .monthly])
            XCTAssertEqual(viewModel.defaultPlan, .lifetime)

            _ = try drawPaywall(viewModel, on: phone, name: "paywall-lifetime-monthly-\(tag(phone))")
            XCTAssertEqual(viewModel.selectedPlan, .lifetime, "lifetime is selected when the paywall opens")
            XCTAssertEqual(viewModel.currentPackage?.packageType, .lifetime)

            let monthly = PaywallViewModel(fixtureOffering: offering(withLifetime: true))
            _ = try drawPaywall(monthly, on: phone, name: "paywall-lifetime-monthly-picked-\(tag(phone))", select: .monthly)
            XCTAssertEqual(monthly.currentPackage?.packageType, .monthly)
        }
    }

    /// A one-time purchase never promises a trial, whatever the eligibility
    /// check says before it has loaded.
    func testLifetimeNeverClaimsATrial() {
        let viewModel = PaywallViewModel(fixtureOffering: offering(withLifetime: true))
        XCTAssertFalse(viewModel.isTrialEligible(for: .lifetime))
        XCTAssertFalse(viewModel.startsWithFreeTrial(for: .lifetime))
        XCTAssertNil(viewModel.trialBadge(for: .lifetime))
        XCTAssertEqual(viewModel.lifetimePrice, "$55.99")
    }

    /// The lifetime line is its own text, not either subscription line.
    func testLifetimeDisclosureIsNotASubscriptionLine() {
        XCTAssertNotEqual(PaywallCopy.lifetimeDisclosure, PaywallCopy.disclosure(startsWithFreeTrial: false))
        XCTAssertNotEqual(PaywallCopy.lifetimeDisclosure, PaywallCopy.disclosure(startsWithFreeTrial: true))
        XCTAssertFalse(PaywallCopy.lifetimeDisclosure.isEmpty)
    }

    // MARK: - One-time offer

    /// The lifetime offer: a cheaper lifetime product, with the percentage
    /// worked out from the two lifetime prices ($55.99 and $27.99: 50%).
    func testLifetimeOfferComputesItsDiscountFromTheTwoLifetimePrices() throws {
        let offer = OneTimeOfferViewModel(fixturePackage: discountedLifetimePackage, regularLifetime: lifetimePackage)
        XCTAssertTrue(offer.isLifetime)
        XCTAssertEqual(offer.savingsPercent, 50)
        XCTAssertEqual(offer.fullPriceString, "$55.99")
        XCTAssertEqual(offer.introPriceString, "$27.99")
        XCTAssertEqual(offer.heroLine, OneTimeOfferCopy.lifetimeDiscountLine)
        XCTAssertEqual(offer.disclosure, OneTimeOfferCopy.lifetimeDisclosure(price: "$27.99"))

        for phone in Self.phones {
            let viewModel = OneTimeOfferViewModel(fixturePackage: discountedLifetimePackage, regularLifetime: lifetimePackage)
            // Already "shown": drawing it must not spend anyone's offer or
            // report a view.
            viewModel.shownAt = Date()
            let view = OneTimeOfferView(viewModel: viewModel, onFinish: {}).environmentObject(AuthManager())
            let image = try draw(view, on: phone, name: "offer-lifetime-\(tag(phone))")
            XCTAssertEqual(image.size, phone.size)
        }
    }

    /// Truncated, never rounded up, and no claim at all when the "discount"
    /// is not one.
    func testLifetimeDiscountPercentage() {
        XCTAssertEqual(OneTimeOfferPricing.savingsPercent(fullPrice: 149.99, discountedPrice: 89.99), 40)
        XCTAssertEqual(OneTimeOfferPricing.savingsPercent(fullPrice: 149.99, discountedPrice: 74.99), 50)
        XCTAssertEqual(OneTimeOfferPricing.savingsPercent(fullPrice: 100, discountedPrice: 50.5), 49, "49.5% is 49, not 50")
        XCTAssertNil(OneTimeOfferPricing.savingsPercent(fullPrice: 89.99, discountedPrice: 149.99))
        XCTAssertNil(OneTimeOfferPricing.savingsPercent(fullPrice: 149.99, discountedPrice: 149.99))
        XCTAssertNil(OneTimeOfferPricing.savingsPercent(fullPrice: 149.99, discountedPrice: 0))
        XCTAssertNil(OneTimeOfferPricing.savingsPercent(fullPrice: 0, discountedPrice: 0))
    }
}
