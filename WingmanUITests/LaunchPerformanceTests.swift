//
//  LaunchPerformanceTests.swift
//  WingmanUITests
//
//  Cold-launch timing, used as the before/after reference for the
//  localization work (requirement: no performance change for English users).
//  Numbers from a Debug build on a simulator are only meaningful relative to
//  each other on the same machine and device — compare runs, not absolutes.
//

import XCTest

final class LaunchPerformanceTests: XCTestCase {

    func testColdLaunch() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
