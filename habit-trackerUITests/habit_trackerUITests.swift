import XCTest

final class habit_trackerUITests: XCTestCase {

  var app: XCUIApplication!
  private let defaultTimeout: TimeInterval = 3
  private let pollInterval: TimeInterval = 0.03

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launch()
  }

  // MARK: - Launch, Dates, and Intention Editing

  @MainActor
  func testLaunchDateHeaderAndIntentionEditing() throws {
    let goalsHeader = app.staticTexts["Goals"]
    XCTAssertTrue(
      goalsHeader.waitForExistence(timeout: defaultTimeout),
      "Goals header should appear on launch"
    )

    let todayStr = DayBoundaryKey.todayDisplay()
    #if os(macOS)
    let todayHeader = app.buttons[
      "dateHeader-\(DayBoundaryKey.today())"
    ]
    XCTAssertTrue(
      todayHeader.waitForExistence(timeout: defaultTimeout),
      "Today's date \(todayStr) should appear in header"
    )
    todayHeader.click()
    #else
    let todayLabel = app.staticTexts[todayStr]
    XCTAssertTrue(
      todayLabel.exists,
      "Today's date \(todayStr) should appear in header"
    )
    todayLabel.tap()
    #endif
    XCTAssertTrue(app.staticTexts["Today I will..."].exists)

    let field = try XCTUnwrap(
      findIntentionField(),
      "Intention input field should exist"
    )
    field.tap()
    field.typeText("ship the habit tracker")

    let value = field.value as? String ?? ""
    XCTAssertTrue(
      value.contains("ship the habit tracker"),
      "Intention text should contain typed text, "
        + "got: \(value)"
    )
  }

  // MARK: - Goal Grid Workflow

  @MainActor
  func testGoalGridWorkflow() throws {
    addGoalWithName("Exercise")
    XCTAssertTrue(
      goalFieldExists(withName: "Exercise"),
      "Goal name 'Exercise' should appear after submission"
    )

    addGoalWithName("Meditate")
    tapTodayCell(forGoalNamed: "Meditate")
    tapTodayCell(forGoalNamed: "Meditate")

    addGoalWithName("OldName")
    let goalField = try XCTUnwrap(
      findGoalField(withName: "OldName")
    )

    // Double-tap to enter edit mode
    #if os(macOS)
    goalField.doubleClick()
    #else
    goalField.doubleTap()
    #endif

    // The field should now be enabled/focused
    let editField = try XCTUnwrap(
      findEditingGoalField(),
      "Edit field should be active on double-tap"
    )

    // Clear existing text and type new name
    #if os(macOS)
    editField.typeKey("a", modifierFlags: .command)
    #else
    editField.tap(withNumberOfTaps: 3, numberOfTouches: 1)
    #endif
    editField.typeText("NewName\n")

    // New name should appear
    XCTAssertTrue(
      goalFieldExists(withName: "NewName"),
      "Renamed goal 'NewName' should appear"
    )

    addGoalWithName("Alpha")
    addGoalWithName("Beta")
    addGoalWithName("Gamma")

    let alpha = try XCTUnwrap(findGoalField(withName: "Alpha"))
    let beta = try XCTUnwrap(findGoalField(withName: "Beta"))
    let gamma = try XCTUnwrap(findGoalField(withName: "Gamma"))

    XCTAssertLessThan(
      alpha.frame.minY, beta.frame.minY,
      "Alpha should appear above Beta"
    )
    XCTAssertLessThan(
      beta.frame.minY, gamma.frame.minY,
      "Beta should appear above Gamma"
    )

    for i in 1...8 {
      addGoalWithName("Goal \(i)")
    }
    let goalsHeader = app.staticTexts["Goals"]
    XCTAssertTrue(
      goalsHeader.waitForExistence(timeout: defaultTimeout)
    )

    app.swipeUp()

    XCTAssertNotNil(
      waitUntil { goalsHeader.isHittable ? goalsHeader : nil },
      "Goals header should remain visible (pinned) "
        + "after scrolling"
    )
  }

  @MainActor
  func testExportSheetOpens() throws {
    let exportButton = app.buttons["exportHabitDataButton"]
    XCTAssertTrue(
      exportButton.waitForExistence(timeout: defaultTimeout)
    )
    #if os(macOS)
    exportButton.click()
    #else
    exportButton.tap()
    #endif

    XCTAssertTrue(
      app.navigationBars["Export Habit Data"]
        .waitForExistence(timeout: defaultTimeout)
        || app.staticTexts["Export Habit Data"]
          .waitForExistence(timeout: defaultTimeout)
    )
    XCTAssertTrue(
      app.buttons["saveJSONExportButton"].exists
    )
    XCTAssertTrue(
      app.staticTexts["Automatic Weekly Backups"].exists
    )
  }

  @MainActor
  func testCloudSyncStatusSheetOpens() throws {
    let syncButton = app.buttons["cloudSyncStatusButton"]
    XCTAssertTrue(
      syncButton.waitForExistence(timeout: defaultTimeout)
    )
    #if os(macOS)
    syncButton.click()
    #else
    syncButton.tap()
    #endif

    XCTAssertTrue(
      app.navigationBars["Cloud Sync"]
        .waitForExistence(timeout: defaultTimeout)
        || app.staticTexts["Cloud Sync"]
          .waitForExistence(timeout: defaultTimeout)
    )
    XCTAssertTrue(
      app.staticTexts["Recent CloudKit Activity"].exists
    )
    XCTAssertTrue(
      app.buttons["Check iCloud Account Again"].exists
    )
  }

  @MainActor
  func testArchivedGoalCanBeRestored() throws {
    addGoalWithName("Retired")
    addGoalWithName("Kept")

    archiveGoal(named: "Retired")
    XCTAssertNil(
      waitUntil { findGoalField(withName: "Retired") },
      "Archived goal should leave the grid"
    )

    let goalFieldCount = goalNameFieldCount()
    longPressAddGoalButton()

    XCTAssertTrue(
      app.navigationBars["Archived Goals"]
        .waitForExistence(timeout: defaultTimeout)
        || app.staticTexts["Archived Goals"]
          .waitForExistence(timeout: defaultTimeout)
    )
    XCTAssertTrue(app.staticTexts["Retired"].exists)

    let restoreButton = app.buttons["restoreGoalButton"]
      .firstMatch
    XCTAssertTrue(
      restoreButton.waitForExistence(timeout: defaultTimeout)
    )
    tap(restoreButton)

    let doneButton = app.buttons["Done"].firstMatch
    if doneButton.waitForExistence(timeout: defaultTimeout) {
      tap(doneButton)
    }

    let restored = waitForGoalField(withName: "Retired")
    XCTAssertNotNil(
      restored,
      "Restored goal should return to the grid"
    )
    let kept = try XCTUnwrap(findGoalField(withName: "Kept"))
    XCTAssertLessThan(
      kept.frame.minY, try XCTUnwrap(restored).frame.minY,
      "Restored goal should land below the active goals"
    )
    XCTAssertEqual(
      goalNameFieldCount(), goalFieldCount + 1,
      "Long pressing the plus should unarchive without "
        + "also adding an empty goal"
    )
  }

  // MARK: - Helpers

  /// Long presses the plus button and picks the unarchive
  /// item from the context menu it opens.
  @MainActor
  private func longPressAddGoalButton() {
    let btn = app.buttons["addGoalButton"]
    XCTAssertTrue(
      btn.waitForExistence(timeout: defaultTimeout),
      "Add goal button should exist"
    )
    #if os(macOS)
    btn.rightClick()
    let restoreItem = app.menuItems["Restore Archived Goal"]
    XCTAssertTrue(
      restoreItem.waitForExistence(timeout: defaultTimeout),
      "Restore menu item should appear on the plus button"
    )
    restoreItem.click()
    #else
    btn.press(forDuration: 1.2)
    let restoreItem = app.buttons["Restore Archived Goal"]
    XCTAssertTrue(
      restoreItem.waitForExistence(timeout: defaultTimeout),
      "Restore menu item should appear on the plus button"
    )
    restoreItem.tap()
    #endif
  }

  /// Number of goal rows currently in the grid.
  @MainActor
  private func goalNameFieldCount() -> Int {
    [app.textFields, app.textViews]
      .map { $0.matching(identifier: "goalNameField").count }
      .reduce(0, +)
  }

  @MainActor
  private func tap(_ element: XCUIElement) {
    #if os(macOS)
    element.click()
    #else
    element.tap()
    #endif
  }

  @MainActor
  private func archiveGoal(named name: String) {
    guard let goalField = waitForGoalField(withName: name)
    else {
      XCTFail("Goal name '\(name)' should exist")
      return
    }

    let center = goalField.coordinate(
      withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
    )
    #if os(macOS)
    center.rightClick()
    let archiveItem = app.menuItems["Archive Goal"]
    XCTAssertTrue(
      archiveItem.waitForExistence(timeout: defaultTimeout),
      "Archive Goal menu item should appear"
    )
    archiveItem.click()
    #else
    center.press(forDuration: 1.2)
    let archiveItem = app.buttons["Archive Goal"]
    XCTAssertTrue(
      archiveItem.waitForExistence(timeout: defaultTimeout),
      "Archive Goal menu item should appear"
    )
    archiveItem.tap()
    #endif
  }

  @MainActor
  private func tapAddGoalButton() {
    let btn = app.buttons["addGoalButton"]
    XCTAssertTrue(
      btn.waitForExistence(timeout: defaultTimeout),
      "Add goal button should exist"
    )
    #if os(macOS)
    btn.click()
    #else
    btn.tap()
    #endif
  }

  /// Finds the currently editing (enabled/focused) goal
  /// name field, polling until one becomes enabled.
  @MainActor
  private func findEditingGoalField() -> XCUIElement? {
    waitUntil {
      for query in [
        app.textFields, app.textViews
      ] {
        let fields = query.matching(
          identifier: "goalNameField"
        )
        for i in 0..<fields.count {
          let f = fields.element(boundBy: i)
          if f.exists && f.isEnabled { return f }
        }
      }
      return nil
    }
  }

  /// Finds a goal name field displaying the given name.
  @MainActor
  private func findGoalField(
    withName name: String
  ) -> XCUIElement? {
    // Goal names are in disabled TextFields with the
    // name as the value
    for query in [
      app.textFields, app.textViews
    ] {
      let fields = query.matching(
        identifier: "goalNameField"
      )
      for i in 0..<fields.count {
        let f = fields.element(boundBy: i)
        if f.exists,
          let val = f.value as? String, val == name
        {
          return f
        }
      }
    }
    return nil
  }

  @MainActor
  private func findIntentionField() -> XCUIElement? {
    waitUntil {
      let textField = app.textFields["intentionField"]
      if textField.exists { return textField }

      let textView = app.textViews["intentionField"]
      if textView.exists { return textView }

      return nil
    }
  }

  @MainActor
  private func tapTodayCell(forGoalNamed name: String) {
    guard let goalField = waitForGoalField(withName: name)
    else {
      XCTFail("Goal name '\(name)' should exist")
      return
    }

    let goalFrame = goalField.frame
    let tapPoint = CGPoint(
      x: goalFrame.maxX + 40,
      y: goalFrame.midY
    )
    app.coordinate(withNormalizedOffset: .zero)
      .withOffset(
        CGVector(dx: tapPoint.x, dy: tapPoint.y)
      )
      .tap()
  }

  @MainActor
  private func waitForGoalField(
    withName name: String
  ) -> XCUIElement? {
    waitUntil {
      findGoalField(withName: name)
    }
  }

  /// Checks if a goal field with the given name exists.
  @MainActor
  private func goalFieldExists(
    withName name: String
  ) -> Bool {
    waitForGoalField(withName: name) != nil
  }

  @MainActor
  private func addGoalWithName(_ name: String) {
    tapAddGoalButton()

    if let field = findEditingGoalField() {
      field.typeText("\(name)\n")
    }

    XCTAssertNotNil(
      waitForGoalField(withName: name),
      "Goal name '\(name)' should appear after submission"
    )
  }

  @MainActor
  private func waitUntil(
    timeout: TimeInterval? = nil,
    _ query: () -> XCUIElement?
  ) -> XCUIElement? {
    let deadline = Date().addingTimeInterval(
      timeout ?? defaultTimeout
    )
    while Date() < deadline {
      if let element = query() { return element }
      RunLoop.current.run(
        until: Date().addingTimeInterval(pollInterval)
      )
    }
    return query()
  }
}

private enum DayBoundaryKey {
  static func today() -> String {
    formatted(as: "yyyy-MM-dd")
  }

  /// The logical day as the date header renders it, e.g. "8/10".
  static func todayDisplay() -> String {
    formatted(as: "M/d")
  }

  /// Applies the app's 4:00 AM logical-day boundary, so tests
  /// run between midnight and 4:00 AM expect yesterday's date.
  private static func formatted(as format: String) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = format
    let adjustedDate = Date().addingTimeInterval(-4 * 60 * 60)
    return formatter.string(from: adjustedDate)
  }
}
