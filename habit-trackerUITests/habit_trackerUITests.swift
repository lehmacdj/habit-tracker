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

    let df = DateFormatter()
    df.dateFormat = "M/d"
    let todayStr = df.string(from: Date())
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

  // MARK: - Helpers

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
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    let adjustedDate = Date().addingTimeInterval(-4 * 60 * 60)
    return formatter.string(from: adjustedDate)
  }
}
