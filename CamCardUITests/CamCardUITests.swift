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

        let photo = app.buttons.matching(identifier: "album-photo").firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 8), app.debugDescription)
        let done = app.buttons["album-done"]
        XCTAssertFalse(done.isEnabled)
        photo.tap()
        XCTAssertTrue(done.isEnabled)
        XCTAssertFalse(app.staticTexts["scan-result"].exists)
        done.tap()

        XCTAssertTrue(app.staticTexts["scan-result"].waitForExistence(timeout: 25))
        let company = app.descendants(matching: .any)["field-公司"]
        XCTAssertEqual(company.value as? String, "Northglass Studio")

        app.buttons["scan-crop"].tap()
        XCTAssertTrue(app.buttons["crop-rotate"].waitForExistence(timeout: 5))
        app.buttons["crop-rotate"].tap()
        app.buttons["crop-cancel"].tap()
        XCTAssertEqual(company.value as? String, "Northglass Studio")

        app.buttons["scan-crop"].tap()
        app.buttons["crop-done"].tap()
        let save = app.buttons["scan-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 25))
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: save)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 25), .completed)
        save.tap()
        XCTAssertTrue(app.staticTexts["名片详情"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Northglass Studio"].exists)
        app.buttons["detail-back"].tap()
        XCTAssertTrue(app.staticTexts["card-count"].label.contains("1张"))
    }

    func testLibrarySearchAndGroupCreation() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-cards"]
        app.launch()

        app.buttons["library-search"].tap()
        let search = app.textFields["search-query"]
        search.tap()
        search.typeText("northglass")
        XCTAssertTrue(app.buttons["Mara Quill"].exists)
        app.navigationBars["搜索"].buttons.firstMatch.tap()

        app.buttons["library-groups"].tap()
        app.buttons["新建分组"].tap()
        let dialog = app.alerts["新建分组"]
        dialog.textFields.firstMatch.typeText("Review")
        dialog.buttons["好"].tap()
        XCTAssertTrue(app.buttons["Review (0)"].exists)
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
