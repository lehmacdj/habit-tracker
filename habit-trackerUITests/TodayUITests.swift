import XCTest

@MainActor
final class TodayUITests: XCTestCase {
  private var app: XCUIApplication!
  private var key: String {
    let now = Date()
    let calendar = Calendar.current
    let adjusted = calendar.component(.hour, from: now) < 4
      ? calendar.date(byAdding: .day, value: -1, to: now)! : now
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    return formatter.string(from: adjusted)
  }

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["--uitesting", "--uitesting-history"]
    app.launch()
  }

  private func goalID(_ index: Int) -> String {
    "00000000-0000-0000-0000-00000000000\(index)"
  }

  private func status(_ index: Int) -> XCUIElement {
    app.buttons["completion-\(goalID(index))-\(key)"]
  }

  private func name(_ text: String) -> XCUIElement {
    app.descendants(matching: .any).matching(NSPredicate(
      format: "identifier == 'goalNameField' AND value == %@", text
    )).firstMatch
  }

  private func startDay() {
    let button = app.buttons["continueIntentionButton"]
    XCTAssertTrue(button.waitForExistence(timeout: 5))
    button.tap()
    XCTAssertTrue(app.scrollViews["todayChecklist"].waitForExistence(timeout: 5))
  }

  private func choose(_ title: String, for index: Int) {
    status(index).press(forDuration: 1.2)
    let action = app.buttons[title]
    XCTAssertTrue(action.waitForExistence(timeout: 3))
    action.tap()
  }

  func testPromptNavigationForegroundAndWidgetLink() throws {
    XCTAssertTrue(app.buttons["continueIntentionButton"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["showGridButton"].exists)
    XCTAssertFalse(app.scrollViews["todayChecklist"].exists)
    XCTAssertTrue(app.buttons["cloudSyncStatusButton"].exists)
    XCTAssertTrue(app.buttons["exportHabitDataButton"].exists)
    app.swipeLeft()
    XCTAssertFalse(app.scrollViews["habitGrid"].exists)
    startDay()
    app.scrollViews["todayChecklist"].swipeLeft()
    XCTAssertTrue(app.scrollViews["habitGrid"].waitForExistence(timeout: 5))
    XCUIDevice.shared.press(.home)
    app.activate()
    XCTAssertTrue(app.scrollViews["habitGrid"].waitForExistence(timeout: 5))
    app.open(try XCTUnwrap(URL(string: "habit-tracker://today")))
    XCTAssertTrue(app.buttons["continueIntentionButton"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.scrollViews["habitGrid"].exists)
    startDay()
    app.buttons["showGridButton"].tap()
    app.buttons["showTodayButton"].tap()
    XCTAssertTrue(app.buttons["continueIntentionButton"].waitForExistence(timeout: 5))
    app.buttons["exportHabitDataButton"].tap()
    XCTAssertTrue(app.buttons["saveJSONExportButton"].waitForExistence(timeout: 5))
    app.open(try XCTUnwrap(URL(string: "habit-tracker://today")))
    XCTAssertTrue(app.buttons["continueIntentionButton"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["saveJSONExportButton"].exists)
  }

  func testWrittenIntentionUsesSharedHeadingOnBothScreens() {
    let field = app.descendants(matching: .any)["intentionField"]
    XCTAssertTrue(field.waitForExistence(timeout: 5))
    field.tap()
    field.typeText("Make room for rest")
    // Typing and autosave must not dismiss the prompt.
    XCTAssertTrue(app.buttons["continueIntentionButton"].exists)
    startDay()
    app.buttons["showGridButton"].tap()
    XCTAssertEqual(app.descendants(matching: .any)["intentionField"].value as? String,
      "Make room for rest")
    app.buttons["showTodayButton"].tap()
    XCTAssertTrue(app.scrollViews["todayChecklist"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.buttons["continueIntentionButton"].exists)
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Today checklist"
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }

  func testFinishedHabitsInterleaveAndClearWithOneTap() {
    startDay()
    choose("Skip", for: 2)
    XCTAssertTrue(status(2).waitForNonExistence(timeout: 3))
    status(1).tap()
    XCTAssertTrue(status(1).waitForNonExistence(timeout: 3))
    app.buttons["toggleFinishedButton"].tap()
    XCTAssertTrue(status(2).waitForExistence(timeout: 3))
    XCTAssertLessThan(name("History 1").frame.minY, name("History 2").frame.minY)
    XCTAssertLessThan(name("History 2").frame.minY, name("History 3").frame.minY)
    XCTAssertEqual(status(2).value as? String, "skipped")
    status(2).tap()
    XCTAssertEqual(status(2).value as? String, "unmarked")
    app.buttons["toggleFinishedButton"].tap()
    XCTAssertFalse(status(1).exists)
    XCTAssertTrue(status(2).exists)
    app.buttons["showGridButton"].tap()
    app.buttons["showTodayButton"].tap()
    startDay()
    XCTAssertFalse(status(1).exists)
    XCTAssertTrue(status(2).exists)
  }

  func testDragAcrossHiddenHabitChangesGridOrder() {
    startDay()
    status(2).tap()
    XCTAssertTrue(status(2).waitForNonExistence(timeout: 3))
    let handle = app.images["reorder-\(goalID(3))"]
    XCTAssertTrue(handle.exists)
    handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
      .press(
        forDuration: 0.8,
        thenDragTo: name("History 1").coordinate(
          withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
        ),
        withVelocity: .slow, thenHoldForDuration: 0.5
      )
    let reordered = NSPredicate { [self] _, _ in
      name("History 3").frame.minY < name("History 1").frame.minY
    }
    XCTAssertEqual(XCTWaiter.wait(for: [
      XCTNSPredicateExpectation(predicate: reordered, object: nil)
    ], timeout: 3), .completed)
    app.buttons["toggleFinishedButton"].tap()
    XCTAssertLessThan(name("History 1").frame.minY, name("History 2").frame.minY)
    app.buttons["showGridButton"].tap()
    XCTAssertTrue(app.scrollViews["habitGrid"].waitForExistence(timeout: 5))
    XCTAssertLessThan(name("History 3").frame.minY, name("History 1").frame.minY)
    XCTAssertLessThan(name("History 1").frame.minY, name("History 2").frame.minY)
  }

  func testFailingLastHabitSuppressesCelebrationAndSkipAllowsIt() {
    startDay()
    status(1).tap()
    XCTAssertTrue(status(1).waitForNonExistence(timeout: 3))
    status(2).tap()
    XCTAssertTrue(status(2).waitForNonExistence(timeout: 3))
    choose("Fail", for: 3)
    XCTAssertTrue(app.staticTexts["All done for today"].waitForExistence(timeout: 3))
    XCTAssertFalse(app.images["todayCelebration"].exists)
    app.buttons["toggleFinishedButton"].tap()
    status(3).tap()
    choose("Skip", for: 3)
    XCTAssertTrue(app.images["todayCelebration"].waitForExistence(timeout: 3))
    app.buttons["toggleFinishedButton"].tap()
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = "Finished today"
    screenshot.lifetime = .keepAlways
    add(screenshot)
    app.buttons["showGridButton"].tap()
    app.buttons["showTodayButton"].tap()
    startDay()
    XCTAssertTrue(app.images["todayCelebration"].waitForExistence(timeout: 3))
  }

  func testTodaySharesNotesRenameAndArchiveActions() {
    startDay()
    choose("Add Note", for: 1)
    let editor = app.textViews["completionNoteEditor"]
    XCTAssertTrue(editor.waitForExistence(timeout: 3))
    editor.tap()
    editor.typeText("Take a shorter walk")
    app.buttons["saveCompletionNoteButton"].tap()
    XCTAssertTrue(status(1).waitForExistence(timeout: 3))
    XCTAssertTrue((status(1).value as? String ?? "").contains("has note"))
    let field = name("History 1")
    field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).doubleTap()
    field.typeText(" updated\n")
    XCTAssertTrue(name("History 1 updated").waitForExistence(timeout: 3))
    name("History 1 updated").coordinate(
      withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
    ).press(forDuration: 1.2)
    app.buttons["Archive Goal"].tap()
    XCTAssertFalse(status(1).exists)
    app.buttons["addGoalButton"].tap()
    let editing = app.descendants(matching: .any).matching(NSPredicate(
      format: "identifier == 'goalNameField' AND enabled == true"
    )).firstMatch
    XCTAssertTrue(editing.waitForExistence(timeout: 3))
    editing.typeText("New habit\n")
    XCTAssertTrue(name("New habit").waitForExistence(timeout: 3))
    app.buttons["showGridButton"].tap()
    XCTAssertTrue(name("New habit").waitForExistence(timeout: 3))
    XCTAssertFalse(name("History 1 updated").exists)
  }
}
