//
//  HomeGreetingTests.swift
//  WingmanTests
//
//  The Home header used to say "Good Morning," at every hour. It now follows
//  the device's local hour: morning 05:00–11:59, afternoon 12:00–17:59,
//  evening otherwise. These pin the boundaries.
//

import XCTest
@testable import Wingman

final class HomeGreetingTests: XCTestCase {

    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }()

    private func greeting(_ hour: Int, _ minute: Int = 0) -> String {
        let date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 11, hour: hour, minute: minute))!
        return HomeView.greeting(at: date, calendar: calendar)
    }

    func testMorning() {
        XCTAssertEqual(greeting(5), "Good Morning,")
        XCTAssertEqual(greeting(8, 30), "Good Morning,")
        XCTAssertEqual(greeting(11, 59), "Good Morning,")
    }

    func testAfternoon() {
        XCTAssertEqual(greeting(12), "Good Afternoon,")
        XCTAssertEqual(greeting(17, 59), "Good Afternoon,")
    }

    func testEveningIncludesLateNight() {
        XCTAssertEqual(greeting(18), "Good Evening,")
        XCTAssertEqual(greeting(23, 59), "Good Evening,")
        XCTAssertEqual(greeting(0), "Good Evening,")
        XCTAssertEqual(greeting(4, 59), "Good Evening,")
    }
}
