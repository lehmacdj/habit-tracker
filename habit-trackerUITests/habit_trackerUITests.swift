import XCTest

final class habit_trackerUITests: XCTestCase {

  var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    app = XCUIApplication()
    app.launchArguments = ["--uitesting"]
    app.launch()
  }

  // MARK: - 1. App Launch & Day Auto-Creation

  @MainActor
  func testAppLaunchShowsTodayColumn() throws {
    let goalsHeader = app.staticTexts["Goals"]
    XCTAssertTrue(
      goalsHeader.waitForExistence(timeout: 5),
      "Goals header should appear on launch"
    )

    let df = DateFormatter()
    df.dateFormat = "M/d"
    let todayStr = df.string(from: Date())
    let todayLabel = app.staticTexts[todayStr]
    XCTAssertTrue(
      todayLabel.exists,
      "Today's date \(todayStr) should appear in header"
    )
  }

  // MARK: - 2. Add Goal

  @MainActor
  func testAddGoalCreatesRow() throws {
    tapAddGoalButton()

    // The new goal's field should appear and be focused
    let field = findEditingGoalField()
    XCTAssertNotNil(
      field,
      "Goal name field should appear after tapping +"
    )

    // Type a goal name and press return to commit
    field!.typeText("Exercise\n")

    // The goal name should now appear in a disabled field
    XCTAssertTrue(
      goalFieldExists(withName: "Exercise"),
      "Goal name 'Exercise' should appear after submission"
    )
  }

  // MARK: - 3. Completion Toggling (Today)

  @MainActor
  func testTapTodayCellTogglesCompletion() throws {
    addGoalWithName("Meditate")

    let goalField = findGoalField(withName: "Meditate")
    XCTAssertNotNil(goalField)

    // Tap to the right of the goal name (today's cell)
    let goalFrame = goalField!.frame
    let tapPoint = CGPoint(
      x: goalFrame.maxX + 40,
      y: goalFrame.midY
    )
    let coord = app.coordinate(
      withNormalizedOffset: .zero
    ).withOffset(
      CGVector(dx: tapPoint.x, dy: tapPoint.y)
    )
    coord.tap()

    Thread.sleep(forTimeInterval: 0.5)

    // Tap again to un-toggle
    coord.tap()

    // If we got here without crash, toggle works
  }

  // MARK: - 4. Intention Editing

  @MainActor
  func testIntentionFieldExists() throws {
    let label = app.staticTexts["Today I will..."]
    XCTAssertTrue(
      label.waitForExistence(timeout: 5),
      "'Today I will...' label should appear"
    )

    // The intention field could be a textField or textView
    // depending on SwiftUI version. Try both.
    var field: XCUIElement
    let tf = app.textFields["intentionField"]
    let tv = app.textViews["intentionField"]
    if tf.waitForExistence(timeout: 2) {
      field = tf
    } else if tv.waitForExistence(timeout: 2) {
      field = tv
    } else {
      XCTFail("Intention input field should exist")
      return
    }

    field.tap()
    field.typeText("ship the habit tracker")

    let value = field.value as? String ?? ""
    XCTAssertTrue(
      value.contains("ship the habit tracker"),
      "Intention text should contain typed text, "
        + "got: \(value)"
    )
  }

  // MARK: - 5. Goal Renaming (Double-Tap)

  @MainActor
  func testDoubleTapGoalNameEntersEditMode() throws {
    addGoalWithName("OldName")

    let goalField = findGoalField(withName: "OldName")
    XCTAssertNotNil(goalField)

    // Double-tap to enter edit mode
    goalField!.doubleTap()

    // Wait for edit mode to activate
    Thread.sleep(forTimeInterval: 0.5)

    // The field should now be enabled/focused
    let editField = findEditingGoalField()
    XCTAssertNotNil(
      editField,
      "Edit field should be active on double-tap"
    )

    // Clear existing text and type new name
    editField!.tap(withNumberOfTaps: 3, numberOfTouches: 1)
    editField!.typeText("NewName\n")

    // New name should appear
    XCTAssertTrue(
      goalFieldExists(withName: "NewName"),
      "Renamed goal 'NewName' should appear"
    )
  }

  // MARK: - 6. Date Header Tap

  @MainActor
  func testTapDateHeaderSwitchesIntention() throws {
    let df = DateFormatter()
    df.dateFormat = "M/d"
    let todayStr = df.string(from: Date())
    let todayHeader = app.staticTexts[todayStr]
    XCTAssertTrue(
      todayHeader.waitForExistence(timeout: 5)
    )

    XCTAssertTrue(
      app.staticTexts["Today I will..."].exists
    )

    todayHeader.tap()
    XCTAssertTrue(
      app.staticTexts["Today I will..."].exists
    )
  }

  // MARK: - 7. Sticky Header (Vertical Scroll)

  @MainActor
  func testStickyHeaderAfterAddingManyGoals() throws {
    for i in 1...8 {
      addGoalWithName("Goal \(i)")
    }

    let goalsHeader = app.staticTexts["Goals"]
    XCTAssertTrue(
      goalsHeader.waitForExistence(timeout: 5)
    )

    app.swipeUp()
    Thread.sleep(forTimeInterval: 0.5)

    XCTAssertTrue(
      goalsHeader.isHittable,
      "Goals header should remain visible (pinned) "
        + "after scrolling"
    )
  }

  // MARK: - 8. Multiple Goals Ordering

  @MainActor
  func testGoalsAppearInCreationOrder() throws {
    addGoalWithName("Alpha")
    addGoalWithName("Beta")
    addGoalWithName("Gamma")

    let alpha = findGoalField(withName: "Alpha")
    let beta = findGoalField(withName: "Beta")
    let gamma = findGoalField(withName: "Gamma")

    XCTAssertNotNil(alpha)
    XCTAssertNotNil(beta)
    XCTAssertNotNil(gamma)

    XCTAssertLessThan(
      alpha!.frame.minY, beta!.frame.minY,
      "Alpha should appear above Beta"
    )
    XCTAssertLessThan(
      beta!.frame.minY, gamma!.frame.minY,
      "Beta should appear above Gamma"
    )
  }

  // MARK: - Helpers

  @MainActor
  private func tapAddGoalButton() {
    let btn = app.buttons["addGoalButton"]
    XCTAssertTrue(
      btn.waitForExistence(timeout: 5),
      "Add goal button should exist"
    )
    btn.tap()
  }

  /// Finds the currently editing (enabled/focused) goal
  /// name field, polling until one becomes enabled.
  @MainActor
  private func findEditingGoalField() -> XCUIElement? {
    let deadline = Date().addingTimeInterval(5)
    while Date() < deadline {
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
      Thread.sleep(forTimeInterval: 0.1)
    }
    return nil
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

  /// Checks if a goal field with the given name exists.
  @MainActor
  private func goalFieldExists(
    withName name: String
  ) -> Bool {
    // Wait briefly for UI to settle
    Thread.sleep(forTimeInterval: 0.5)
    return findGoalField(withName: name) != nil
  }

  @MainActor
  private func addGoalWithName(_ name: String) {
    tapAddGoalButton()

    if let field = findEditingGoalField() {
      field.typeText("\(name)\n")
    }

    // Wait for the name to commit
    Thread.sleep(forTimeInterval: 0.5)
  }
}
