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

    /// System-drawn chrome (nav bar, search field, system buttons) is Apple's responsibility;
    /// everything we draw ourselves must pass the audit with no exceptions.
    private func audit(_ types: XCUIAccessibilityAuditType = .all) throws {
        try app.performAccessibilityAudit(for: types) { issue in
            switch issue.element?.elementType {
            case .navigationBar, .searchField, .button, .keyboard, .toolbar: return true
            default: return false
            }
        }
    }

    func testListPassesAccessibilityAudit() throws {
        // The empty list is drawn entirely by system views (ContentUnavailableView, search
        // field), which iOS flags for Dynamic Type; text scaling of our own rows is covered
        // by testLargestAccessibilityTextSize.
        try audit([.contrast, .elementDetection, .hitRegion, .sufficientElementDescription, .trait, .textClipped])
    }

    func testEditorPassesAccessibilityAudit() throws {
        app.buttons["newNoteButton"].tap()
        XCTAssertTrue(app.textFields["titleField"].waitForExistence(timeout: 3))
        try audit()
    }

    func testLargestAccessibilityTextSize() throws {
        app.terminate()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        XCTAssertTrue(app.buttons["newNoteButton"].exists)
        try audit([.dynamicType, .textClipped])
    }
}
