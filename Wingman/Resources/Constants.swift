//
//  Constants.swift
//  Wingman
//
//  Created by Adnan Khan on 06/04/2026.
//

import Foundation

struct Constants {
    // MARK: - RevenueCat Configuration
    // Use RevenueCatConfig for API key management with DEBUG/RELEASE build configurations
    static let ENTITLEMENT_ID = RevenueCatConfig.premiumEntitlementId
    static let REVENUE_CAT_API_KEY = RevenueCatConfig.apiKey
    
    // MARK: - Subscription Product IDs
    static let YEARLY_PRODUCT_ID = RevenueCatConfig.ProductIds.yearly
    static let MONTHLY_PRODUCT_ID = RevenueCatConfig.ProductIds.monthly
    static let WINGMAN_MONTHLY_PRODUCT_ID = RevenueCatConfig.ProductIds.monthly
    static let WINGMAN_YEARLY_PRODUCT_ID = RevenueCatConfig.ProductIds.yearly

    // MARK: - Second-Chance Recovery Offer
    static let SECOND_CHANCE_YEARLY_PRODUCT_ID = RevenueCatConfig.ProductIds.yearlyDiscount
    static let SECOND_CHANCE_OFFERING_ID = RevenueCatConfig.SecondChanceOffer.offeringId
    static let SECOND_CHANCE_PACKAGE_ID = RevenueCatConfig.SecondChanceOffer.packageId
    
    // MARK: - URLs
    static let PRIVACY_POLICY_URL = "https://www.getwingman.app/privacy"
    static let TERMS_CONDITIONS_URL = "https://www.getwingman.app/terms"

    // MARK: - PostHog Analytics
    // Project token is public-safe (designed to be bundled in client apps).
    // DEBUG vs Release is tagged via the `environment` super-property at setup.
    static let POSTHOG_PROJECT_TOKEN = "phc_nHqVpjSQBTE4UBm2poiehcb4de92uJirKRMed8nhdurH"
    static let POSTHOG_HOST = "https://us.i.posthog.com"
}
