import XCTest

final class CamCardUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEmptyLibraryAndScannerNavigation() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["card-count"].label.contains("0张"))
        XCTAssertTrue(app.staticTexts["30秒快速认识CC"].exists)
        XCTAssertTrue(app.staticTexts["请输入姓名/公司/职位搜索"].exists)

        app.buttons["open-scanner"].tap()
        XCTAssertTrue(app.buttons["close-scanner"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["scan-photo-picker"].exists)
        app.buttons["close-scanner"].tap()
        XCTAssertTrue(app.staticTexts["card-count"].waitForExistence(timeout: 5))
    }

    func testSimulatorCameraUnavailable() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["open-scanner"].tap()
        app.buttons["scan-shutter"].tap()
        XCTAssertTrue(app.alerts.staticTexts["当前设备无法使用相机，请从相册导入。"].waitForExistence(timeout: 5), app.debugDescription)
        app.alerts.buttons["好"].tap()
        XCTAssertTrue(app.buttons["scan-photo-picker"].exists)
    }

    func testPhotoImportAndManualCrop() {
        let app = XCUIApplication()
        app.launch()
        app.buttons["open-scanner"].tap()
        app.buttons["scan-photo-picker"].tap()

        let photo = app.images.matching(identifier: "PXGGridLayout-Info").firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 8), app.debugDescription)
        photo.tap()

        XCTAssertTrue(app.staticTexts["scan-result"].waitForExistence(timeout: 25))
        let rawText = app.staticTexts["scan-raw-text"]
        XCTAssertTrue(rawText.label.localizedCaseInsensitiveContains("Northglass Studio"))

        app.buttons["scan-crop"].tap()
        XCTAssertTrue(app.buttons["crop-rotate"].waitForExistence(timeout: 5))
        app.buttons["crop-rotate"].tap()
        app.buttons["取消"].tap()
        XCTAssertTrue(rawText.label.localizedCaseInsensitiveContains("Northglass Studio"))

        app.buttons["scan-crop"].tap()
        app.buttons["crop-done"].tap()
        XCTAssertTrue(rawText.waitForExistence(timeout: 25))
        XCTAssertTrue(rawText.label.localizedCaseInsensitiveContains("Northglass Studio"))
    }

    func testDemoCardDetailAndReturn() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-cards"]
        app.launch()

        XCTAssertTrue(app.staticTexts["card-count"].label.contains("1张"))
        let row = app.buttons["card-00000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(row.exists)
        row.tap()

        let detail = app.staticTexts["名片详情"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["detail-name"].label, "Mara Quill")
        XCTAssertTrue(app.staticTexts["Northglass Studio"].exists)
        let email = app.descendants(matching: .any)["email-0"]
        XCTAssertEqual(email.value as? String, "mara@example.com")

        app.buttons["detail-back"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }
}
