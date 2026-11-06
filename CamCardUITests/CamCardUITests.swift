import XCTest

final class CamCardUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEmptyLibraryAndScannerNavigation() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.navigationBars["名片夹"].exists)
        XCTAssertTrue(app.staticTexts["名片（0 张）"].exists)
        XCTAssertTrue(app.staticTexts["还没有名片"].exists)

        app.buttons["open-scanner"].tap()
        XCTAssertTrue(app.navigationBars["扫描名片"].waitForExistence(timeout: 5))
        app.buttons["close-scanner"].tap()
        XCTAssertTrue(app.navigationBars["名片夹"].waitForExistence(timeout: 5))
    }

    func testDemoCardDetailAndReturn() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-cards"]
        app.launch()

        XCTAssertTrue(app.staticTexts["名片（1 张）"].exists)
        let row = app.buttons["card-00000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(row.exists)
        row.tap()

        let detail = app.navigationBars["名片详情"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["detail-name"].label, "Mara Quill")
        XCTAssertTrue(app.staticTexts["Northglass Studio"].exists)
        let email = app.descendants(matching: .any)["email-0"]
        XCTAssertEqual(email.value as? String, "mara@example.com")

        detail.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }
}
