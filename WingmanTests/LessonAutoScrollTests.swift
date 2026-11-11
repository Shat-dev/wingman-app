//
//  LessonAutoScrollTests.swift
//  WingmanTests
//
//  When a lesson page reveals a paragraph that does not fit, the page scrolls
//  only as far as needed to show it, instead of to the padded bottom of the
//  content (which hid most of the page's start on an iPhone SE).
//

import XCTest
@testable import Wingman

final class LessonAutoScrollTests: XCTestCase {

    private let viewport: CGFloat = 540

    private func offset(_ paragraph: CGRect, from current: CGFloat = 0) -> CGFloat {
        ScrollableContentView.offsetShowing(paragraph: paragraph, viewportHeight: viewport, currentOffset: current)
    }

    func testAParagraphThatFitsDoesNotScroll() {
        XCTAssertEqual(offset(CGRect(x: 20, y: 0, width: 335, height: 300)), 0)
        XCTAssertEqual(offset(CGRect(x: 20, y: 310, width: 335, height: 200)), 0)
    }

    /// Second paragraph runs 200pt past the viewport: scroll just enough to
    /// show its last line plus the 16pt margin, not 120pt further.
    func testScrollsOnlyAsFarAsTheNewParagraphNeeds() {
        let second = CGRect(x: 20, y: 330, width: 335, height: 410) // bottom at 740
        XCTAssertEqual(offset(second), 740 + 16 - viewport)
    }

    /// A paragraph taller than the screen is shown from its first line.
    func testATallParagraphIsAlignedToItsTop() {
        let tall = CGRect(x: 20, y: 300, width: 335, height: 700)
        XCTAssertEqual(offset(tall), 300)
    }

    func testAlreadyVisibleParagraphKeepsTheCurrentOffset() {
        let paragraph = CGRect(x: 20, y: 400, width: 335, height: 200)
        XCTAssertEqual(offset(paragraph, from: 200), 200)
    }

    /// Going back to fewer paragraphs: the last one is above the current
    /// offset, so the page moves back up to it.
    func testParagraphAboveTheViewportScrollsBackUp() {
        let first = CGRect(x: 20, y: 0, width: 335, height: 300)
        XCTAssertEqual(offset(first, from: 216), 0)
    }
}
