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
        XCTAssertTrue(app.staticTexts["英语, 简体中文, 繁体中文"].exists)
        let company = app.descendants(matching: .any)["field-公司"]
        XCTAssertEqual(company.value as? String, "Northglass Studio")

        let editorScreenshot = XCTAttachment(screenshot: app.screenshot())
        editorScreenshot.name = "CC-001 编辑名片"
        editorScreenshot.lifetime = .keepAlways
        add(editorScreenshot)

        app.buttons["scan-crop"].tap()
        XCTAssertTrue(app.buttons["crop-rotate"].waitForExistence(timeout: 5))
        app.buttons["crop-rotate"].tap()
        app.buttons["crop-cancel"].tap()
        XCTAssertEqual(company.value as? String, "Northglass Studio")

        let email = app.descendants(matching: .any)["field-工作邮箱-0"]
        XCTAssertEqual(email.value as? String, "mara@example.com")
        email.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        email.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "mara@example.com".count))
        XCTAssertFalse((email.value as? String ?? "").contains("@"))
        app.swipeDown()

        app.buttons["scan-crop"].tap()
        app.buttons["crop-done"].tap()
        let save = app.buttons["scan-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 25))
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: save)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 25), .completed)
        XCTAssertFalse((email.value as? String ?? "").contains("@"))

        app.buttons["scan-name"].tap()
        let givenName = app.textFields["field-given-name"]
        XCTAssertTrue(givenName.waitForExistence(timeout: 5))
        let nameScreenshot = XCTAttachment(screenshot: app.screenshot())
        nameScreenshot.name = "CC-001 姓名子页"
        nameScreenshot.lifetime = .keepAlways
        add(nameScreenshot)
        givenName.tap()
        givenName.typeText("a")
        app.buttons["scan-name-back"].tap()
        XCTAssertTrue(app.buttons["scan-name"].label.contains("Maraa"))

        save.tap()
        XCTAssertTrue(app.staticTexts["名片详情"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Northglass Studio"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["email-0"].exists)
        XCTAssertEqual(app.staticTexts["detail-name"].label, "Maraa Quill")
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
