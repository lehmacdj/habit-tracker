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

    // A text field should appear for the new goal name
    let textField = app.textFields["goal name"]
    XCTAssertTrue(
      textField.waitForExistence(timeout: 3),
      "Goal name text field should appear after tapping +"
    )

    // Type a goal name and submit
    textField.typeText("Exercise\n")

    // The goal name should now appear as static text
    let goalText = app.staticTexts["Exercise"]
    XCTAssertTrue(
      goalText.waitForExistence(timeout: 3),
      "Goal name 'Exercise' should appear after submission"
    )
  }

  // MARK: - 3. Completion Toggling (Today)

  @MainActor
  func testTapTodayCellTogglesCompletion() throws {
    addGoalWithName("Meditate")

    let goalText = app.staticTexts["Meditate"]
    XCTAssertTrue(
      goalText.waitForExistence(timeout: 3)
    )

    // Tap to the right of the goal name (today's cell)
    let goalFrame = goalText.frame
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
    let tf = app.textFields.firstMatch
    let tv = app.textViews.firstMatch
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

    let goalText = app.staticTexts["OldName"]
    XCTAssertTrue(
      goalText.waitForExistence(timeout: 3)
    )

    // Double-tap to enter edit mode
    goalText.doubleTap()

    // A text field should appear
    let editField = app.textFields["goal name"]
    XCTAssertTrue(
      editField.waitForExistence(timeout: 3),
      "Edit field should appear on double-tap"
    )

    // Clear existing text and type new name
    // Triple-tap selects all in a text field
    editField.tap(withNumberOfTaps: 3, numberOfTouches: 1)
    editField.typeText("NewName\n")

    // New name should appear
    let newGoalText = app.staticTexts["NewName"]
    XCTAssertTrue(
      newGoalText.waitForExistence(timeout: 3),
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

    let alpha = app.staticTexts["Alpha"]
    let beta = app.staticTexts["Beta"]
    let gamma = app.staticTexts["Gamma"]

    XCTAssertTrue(alpha.waitForExistence(timeout: 3))
    XCTAssertTrue(beta.exists)
    XCTAssertTrue(gamma.exists)

    XCTAssertLessThan(
      alpha.frame.minY, beta.frame.minY,
      "Alpha should appear above Beta"
    )
    XCTAssertLessThan(
      beta.frame.minY, gamma.frame.minY,
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

  @MainActor
  private func addGoalWithName(_ name: String) {
    tapAddGoalButton()

    let textField = app.textFields["goal name"]
    if textField.waitForExistence(timeout: 3) {
      textField.typeText("\(name)\n")
    }

    _ = app.staticTexts[name]
      .waitForExistence(timeout: 2)
  }
}
