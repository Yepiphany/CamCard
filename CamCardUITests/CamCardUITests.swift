import XCTest

final class CamCardUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testEmptyLibraryAndScannerNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["--empty-library"]
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
        app.launchArguments = ["--test-library", "--reset-test-library"]
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

        app.terminate()
        app.launchArguments = ["--test-library"]
        app.launch()
        XCTAssertTrue(app.staticTexts["card-count"].label.contains("1张"))
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "card-")).firstMatch.tap()
        XCTAssertEqual(app.staticTexts["detail-name"].label, "Maraa Quill")
        app.staticTexts["detail-name"].tap()
        XCTAssertTrue(app.staticTexts["原图"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["无法读取图片"].exists)
        app.buttons["card-image-page-1"].tap()
        XCTAssertTrue(app.staticTexts["校正图"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["无法读取图片"].exists)
        app.buttons["关闭"].tap()

        app.buttons["detail-notes"].tap()
        app.buttons["新增备注"].tap()
        app.buttons["普通备注"].tap()
        let note = app.textViews["note-text"]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        note.tap()
        note.typeText("Simulator note")
        app.buttons["保存"].tap()
        XCTAssertTrue(app.staticTexts["Simulator note"].waitForExistence(timeout: 5))
        app.buttons["notes-back"].tap()
        app.buttons["detail-groups"].tap()
        app.buttons["新建分组"].tap()
        let newGroup = app.alerts["新建分组"]
        newGroup.textFields.firstMatch.typeText("Persisted")
        newGroup.buttons["好"].tap()
        app.buttons["Persisted"].tap()
        app.buttons["完成"].tap()

        app.terminate()
        app.launch()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "card-")).firstMatch.tap()
        XCTAssertTrue(app.buttons["detail-notes"].label.contains("Simulator note"))
        XCTAssertTrue(app.buttons["detail-groups"].label.contains("Persisted"))

        app.buttons["detail-more"].tap()
        attachScreenshot(app, named: "详情更多操作")
        app.buttons["删除"].tap()
        app.alerts["提示"].buttons["取消"].tap()
        XCTAssertTrue(app.staticTexts["detail-name"].exists)
        app.buttons["detail-more"].tap()
        app.buttons["删除"].tap()
        app.alerts["提示"].buttons["删除名片"].tap()
        XCTAssertTrue(app.staticTexts["card-count"].label.contains("0张"))
    }

    func testLibrarySearchAndGroupCreation() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-cards"]
        app.launch()

        app.buttons["library-search"].tap()
        let search = app.textFields["search-query"]
        search.tap()
        search.typeText("northglass")
        XCTAssertTrue(app.staticTexts["名片夹名片 (1)"].waitForExistence(timeout: 5), app.debugDescription)
        app.navigationBars["搜索"].buttons.firstMatch.tap()

        app.buttons["library-groups"].tap()
        app.buttons["新建分组"].tap()
        let dialog = app.alerts["新建分组"]
        dialog.textFields.firstMatch.typeText("Review")
        dialog.buttons["好"].tap()
        let group = app.buttons["Review (0)"]
        XCTAssertTrue(group.exists)
        group.tap()
        app.buttons["group-more"].tap()
        app.buttons["从名片夹中添加"].tap()
        let choice = app.buttons["select-card-00000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(choice.waitForExistence(timeout: 5))
        choice.tap()
        let complete = app.buttons["完成"]
        XCTAssertTrue(complete.isEnabled, app.debugDescription)
        complete.tap()
        let member = app.descendants(matching: .any)["linked-card-00000000-0000-0000-0000-000000000001"]
        XCTAssertTrue(member.waitForExistence(timeout: 5), app.debugDescription)
        attachScreenshot(app, named: "分组内名片")
        app.buttons["group-back"].tap()
        app.buttons["编辑"].tap()
        app.buttons["删除分组 Review"].tap()
        app.alerts["删除分组"].buttons["删除"].tap()
        XCTAssertFalse(app.buttons["删除分组 Review"].exists)
        XCTAssertTrue(app.buttons["未分组 (1)"].exists)
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

        app.buttons["编辑"].tap()
        let name = app.descendants(matching: .any)["edit-姓名"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.5)).tap()
        name.typeText(" Edited")
        app.buttons["取消"].tap()
        XCTAssertEqual(app.staticTexts["detail-name"].label, "Mara Quill")

        app.buttons["编辑"].tap()
        name.coordinate(withNormalizedOffset: CGVector(dx: 0.96, dy: 0.5)).tap()
        name.typeText(" Edited")
        app.buttons["保存"].tap()
        XCTAssertEqual(app.staticTexts["detail-name"].label, "Mara Quill Edited")

        app.buttons["detail-back"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }

    func testContactsExport() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-cards"]
        app.launch()
        app.buttons["card-00000000-0000-0000-0000-000000000001"].tap()
        app.buttons["detail-contacts"].tap()
        XCTAssertTrue(app.staticTexts["iPhone"].waitForExistence(timeout: 5))
        app.buttons["保存"].tap()
        let denied = app.alerts["无法保存名片到通讯录"]
        if denied.waitForExistence(timeout: 3) {
            XCTAssertTrue(denied.buttons["前往设置"].exists)
            denied.buttons["取消"].tap()
            XCTAssertTrue(app.buttons["detail-contacts"].exists)
        } else {
            XCTAssertTrue(app.staticTexts["已存"].waitForExistence(timeout: 8), app.debugDescription)
        }

        app.buttons["detail-more"].tap()
        app.buttons["导出 VCF"].tap()
        XCTAssertTrue(app.staticTexts["已导出 VCF"].waitForExistence(timeout: 8), app.debugDescription)
        XCTAssertTrue(app.buttons["分享 VCF"].exists)
        attachScreenshot(app, named: "VCF 导出确认")
    }

    private func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let evidence = XCTAttachment(screenshot: app.screenshot())
        evidence.name = name
        evidence.lifetime = .keepAlways
        add(evidence)
    }

}
