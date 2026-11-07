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

    func testPhotoAlbumAccessAndCancel() {
        let app = XCUIApplication()
        app.launchArguments = ["--empty-library"]
        app.launch()
        app.buttons["open-scanner"].tap()
        app.buttons["scan-photo-picker"].tap()

        let unavailable = app.staticTexts["无法访问照片"]
        if unavailable.waitForExistence(timeout: 3) {
            XCTAssertTrue(app.buttons["前往设置"].exists)
            XCTAssertFalse(app.buttons.matching(identifier: "album-photo").firstMatch.exists)
            attachScreenshot(app, named: "相册访问被拒")
        } else {
            XCTAssertTrue(app.buttons.matching(identifier: "album-photo").firstMatch.waitForExistence(timeout: 5))
        }
        XCTAssertFalse(app.buttons["album-done"].isEnabled)
        app.buttons["album-cancel"].tap()
        app.buttons["close-scanner"].tap()
        XCTAssertTrue(app.staticTexts["card-count"].label.contains("0张"))
    }

    func testPhotoImportAndManualCrop() {
        let app = XCUIApplication()
        app.launchArguments = ["--test-library", "--reset-test-library", "--test-photo-filenames"]
        app.launch()
        app.buttons["open-scanner"].tap()
        app.buttons["scan-photo-picker"].tap()

        let photo = albumPhoto("CC-001.png", in: app)
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

    func testDifficultFixtureCropAndRecovery() {
        let app = XCUIApplication()
        app.launchArguments = ["--empty-library", "--test-photo-filenames", "--test-invalid-image"]
        app.launch()
        app.buttons["open-scanner"].tap()

        func choose(_ name: String) {
            app.buttons["scan-photo-picker"].tap()
            let photo = albumPhoto(name, in: app)
            XCTAssertTrue(photo.waitForExistence(timeout: 8), app.debugDescription)
            photo.tap()
            app.buttons["album-done"].tap()
        }

        choose("CC-016.png")
        let error = app.alerts.staticTexts["无法读取这张图片，请重新选择。"]
        XCTAssertTrue(error.waitForExistence(timeout: 10), app.debugDescription)
        app.alerts.buttons["好"].tap()
        XCTAssertFalse(app.staticTexts["scan-result"].exists)

        for fixture in ["CC-016.png", "CC-017.png"] {
            choose(fixture)
            XCTAssertTrue(app.staticTexts["scan-result"].waitForExistence(timeout: 25), fixture)
            app.buttons["scan-crop"].tap()
            let corner = app.descendants(matching: .any)["crop-corner-0"]
            XCTAssertTrue(corner.waitForExistence(timeout: 5), app.debugDescription)
            let before = corner.frame
            let start = corner.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 14, dy: 12)))
            XCTAssertGreaterThan(corner.frame.midX, before.midX + 5, fixture)
            attachScreenshot(app, named: "\(fixture) 调整角点")
            app.buttons["crop-done"].tap()
            let save = app.buttons["scan-save"]
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: save)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 25), .completed, fixture)
            XCTAssertFalse(app.alerts.firstMatch.exists, fixture)
            app.buttons["重新拍摄"].tap()
        }
        choose("CC-030.png")
        XCTAssertTrue(app.staticTexts["未识别到文字。可调整裁剪或手动填写。"].waitForExistence(timeout: 25))
        XCTAssertTrue(app.buttons["scan-crop"].exists)
        app.buttons["重新拍摄"].tap()
        app.buttons["close-scanner"].tap()
        XCTAssertTrue(app.staticTexts["card-count"].label.contains("0张"))
    }

    func testDetailOpensContactURLs() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-cards", "--test-open-urls"]
        app.launch()
        app.buttons["card-00000000-0000-0000-0000-000000000001"].tap()

        attachScreenshot(app, named: "名片详情")
        let opened = app.staticTexts["test-opened-url"]
        func check(_ value: String) {
            let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND label == %@", value), object: opened)
            XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 5), .completed)
        }
        app.buttons["detail-call"].tap()
        check("tel:+12025550101")
        app.descendants(matching: .any)["email-0"].tap()
        check("mailto:mara@example.com")
        let website = app.buttons["detail-website"]
        if !website.isHittable { app.swipeUp() }
        website.tap()
        check("https://northglass.example")
    }

    func testCaptureModesAndContinuousAlbum() {
        let app = XCUIApplication()
        app.launchArguments = ["--empty-library", "--test-photo-filenames"]
        app.launch()
        app.buttons["open-scanner"].tap()
        XCTAssertTrue(app.buttons["scan-mode-单张拍摄"].isSelected)
        let continuous = app.buttons["scan-mode-连续拍摄"]
        XCTAssertTrue(continuous.isHittable)
        XCTAssertGreaterThan(continuous.frame.minX, 0)
        XCTAssertTrue(app.staticTexts["请将镜头靠近名片"].exists)
        // Capture the settled full-screen presentation rather than the cover transition.
        RunLoop.current.run(until: Date().addingTimeInterval(0.65))
        attachScreenshot(app, named: "单张拍摄取景")
        app.buttons["scan-mode-二维码"].tap()
        let qrHint = app.staticTexts["扫描 CC 名片二维码，面对面交换名片"]
        XCTAssertTrue(qrHint.exists)
        let torch = app.buttons["轻触照亮"]
        XCTAssertTrue(torch.exists)
        XCTAssertFalse(torch.frame.intersects(qrHint.frame))
        XCTAssertFalse(app.buttons["scan-shutter"].isEnabled)
        attachScreenshot(app, named: "二维码取景")
        app.buttons["scan-mode-多张拍摄"].tap()
        let guide = app.buttons["我知道了"]
        if guide.waitForExistence(timeout: 2) { guide.tap() }
        XCTAssertTrue(app.staticTexts["正在寻找名片边框"].exists)
        attachScreenshot(app, named: "多张拍摄取景")
        app.buttons["scan-mode-连续拍摄"].tap()
        XCTAssertTrue(app.buttons["scan-mode-连续拍摄"].isSelected)
        app.buttons["scan-photo-picker"].tap()
        for name in ["CC-001.png", "CC-017.png"] {
            let photo = albumPhoto(name, in: app)
            XCTAssertTrue(photo.waitForExistence(timeout: 8))
            photo.tap()
        }
        let done = app.buttons["album-done"]
        XCTAssertEqual(done.label, "2 完成")
        done.tap()
        let save = app.buttons["scan-save"]
        XCTAssertTrue(save.waitForExistence(timeout: 25))
        save.tap()
        let next = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND enabled == true"), object: save)
        XCTAssertEqual(XCTWaiter.wait(for: [next], timeout: 25), .completed)
        save.tap()
        XCTAssertTrue(app.staticTexts["名片详情"].waitForExistence(timeout: 8))
        app.buttons["detail-back"].tap()
        XCTAssertTrue(app.staticTexts["card-count"].label.contains("2张"))
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
        app.buttons["search-back"].tap()

        app.buttons["library-search"].tap()
        XCTAssertTrue(app.staticTexts["最近搜索"].exists)
        app.buttons["northglass"].tap()
        XCTAssertTrue(app.staticTexts["名片夹名片 (1)"].exists)
        for query in ["Mara", "Director", "202-555", "mara@example.com", "no-match"] {
            app.buttons["清空搜索"].tap()
            search.tap()
            search.typeText(query)
            if query == "no-match" {
                XCTAssertTrue(app.staticTexts["未找到「no-match」"].exists)
            } else {
                XCTAssertTrue(app.staticTexts["名片夹名片 (1)"].exists)
            }
        }
        app.buttons["清空搜索"].tap()
        app.buttons["清空最近搜索"].tap()
        XCTAssertFalse(app.staticTexts["最近搜索"].exists)
        app.buttons["search-back"].tap()

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
        let name = app.buttons["edit-name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        app.buttons["显示隐藏项"].tap()
        attachScreenshot(app, named: "姓名隐藏项")
        XCTAssertTrue(app.textFields["name-nickname"].exists)
        let givenName = app.textFields["field-given-name"]
        givenName.tap()
        givenName.typeText(" Edited")
        app.buttons["scan-name-back"].tap()
        app.buttons["取消"].tap()
        XCTAssertEqual(app.staticTexts["detail-name"].label, "Mara Quill")

        app.buttons["编辑"].tap()
        name.tap()
        givenName.tap()
        givenName.typeText(" Edited")
        app.buttons["scan-name-back"].tap()
        let company = app.descendants(matching: .any)["edit-公司"]
        company.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.5)).tap()
        company.typeText(" Updated")
        app.buttons["保存"].tap()
        XCTAssertEqual(app.staticTexts["detail-name"].label, "Mara Edited Quill")
        XCTAssertTrue(app.staticTexts["Northglass Studio Updated"].exists)

        app.buttons["detail-back"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }

    func testLibraryQuickActionsAndManualEntry() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-cards"]
        app.launch()

        app.buttons["card-more-00000000-0000-0000-0000-000000000001"].tap()
        XCTAssertTrue(app.staticTexts["更多操作"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["打电话"].exists)
        XCTAssertTrue(app.buttons["分享TA的名片"].exists)
        attachScreenshot(app, named: "名片夹更多操作")
        app.buttons["管理分组"].tap()
        XCTAssertTrue(app.navigationBars["添加到分组"].waitForExistence(timeout: 5))
        app.buttons["完成"].tap()

        app.buttons["card-more-00000000-0000-0000-0000-000000000001"].tap()
        app.buttons["分享TA的名片"].tap()
        XCTAssertTrue(app.staticTexts["已导出 VCF"].waitForExistence(timeout: 5))
        app.buttons["完成"].tap()

        app.buttons["library-add"].tap()
        app.buttons["添加名片"].tap()
        app.buttons["从相册导入"].tap()
        XCTAssertTrue(app.buttons["album-done"].waitForExistence(timeout: 8))
        app.buttons["album-cancel"].tap()
        app.buttons["close-scanner"].tap()

        app.buttons["library-add"].tap()
        app.buttons["添加名片"].tap()
        XCTAssertTrue(app.staticTexts["添加名片"].waitForExistence(timeout: 5))
        app.buttons["手动输入名片"].tap()
        let save = app.buttons["保存"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled)
        app.buttons["添加名片图像"].tap()
        let photo = app.buttons.matching(identifier: "album-photo").firstMatch
        XCTAssertTrue(photo.waitForExistence(timeout: 8))
        photo.tap()
        app.buttons["album-done"].tap()
        XCTAssertTrue(app.buttons["更换名片图像"].waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled)
        attachScreenshot(app, named: "手动输入名片")
        app.buttons["edit-name"].tap()
        let givenName = app.textFields["field-given-name"]
        givenName.tap()
        givenName.typeText("Test Card")
        app.buttons["scan-name-back"].tap()
        save.tap()
        XCTAssertEqual(app.staticTexts["detail-name"].label, "Test Card")
        app.buttons["detail-back"].tap()
        XCTAssertTrue(app.staticTexts["card-count"].label.contains("2张"))
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

    func testVisitEditorAndSavedLog() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo-cards"]
        app.launch()
        app.buttons["card-00000000-0000-0000-0000-000000000001"].tap()
        app.buttons["detail-notes"].tap()
        app.buttons["新增备注"].tap()
        attachScreenshot(app, named: "备注类型")
        app.buttons["拜访日志"].tap()

        let followUp = app.buttons["visit-follow-up"]
        XCTAssertTrue(followUp.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Mara Quill"].exists)
        XCTAssertFalse(app.buttons["保存"].isEnabled)
        XCTAssertTrue(app.buttons["上门拜访"].isSelected)
        app.buttons["电话拜访"].tap()
        XCTAssertTrue(app.buttons["电话拜访"].isSelected)
        attachScreenshot(app, named: "拜访日志")
        followUp.tap()
        let confirm = app.buttons["visit-time-confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        attachScreenshot(app, named: "回访时间滚轮")
        confirm.tap()
        app.buttons["清除回访提醒"].tap()

        let content = app.descendants(matching: .any)["visit-content"]
        content.tap()
        content.typeText("Discussed project")
        app.buttons["保存"].tap()
        XCTAssertTrue(app.staticTexts["Discussed project"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["拜访日志"].exists)
        app.buttons["notes-back"].tap()
        XCTAssertTrue(app.buttons["detail-notes"].label.contains("Discussed project"))
    }

    private func albumPhoto(_ filename: String, in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(identifier: "album-photo")
            .matching(NSPredicate(format: "value =[c] %@", filename)).firstMatch
    }

    private func attachScreenshot(_ app: XCUIApplication, named name: String) {
        let evidence = XCTAttachment(screenshot: app.screenshot())
        evidence.name = name
        evidence.lifetime = .keepAlways
        add(evidence)
    }

}
