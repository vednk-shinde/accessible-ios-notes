import XCTest

/// End-to-end flows plus accessibility audits (Xcode 15+ `performAccessibilityAudit`).
final class AccessibilityUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-disableCloudKit"]
        app.launch()
    }

    func testCreateAndEditNote() {
        app.buttons["newNoteButton"].tap()
        let title = app.textFields["titleField"]
        XCTAssertTrue(title.waitForExistence(timeout: 3))
        title.tap()
        title.typeText("Groceries")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Groceries"].waitForExistence(timeout: 3))
    }

    func testListPassesAccessibilityAudit() throws {
        try app.performAccessibilityAudit()
    }

    func testEditorPassesAccessibilityAudit() throws {
        app.buttons["newNoteButton"].tap()
        XCTAssertTrue(app.textFields["titleField"].waitForExistence(timeout: 3))
        try app.performAccessibilityAudit()
    }

    func testLargestAccessibilityTextSize() throws {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["newNoteButton"].exists)
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped])
    }
}
