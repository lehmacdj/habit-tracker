import CloudKit
import CoreData
import Foundation
import SwiftData
import SwiftUI
import Testing
#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
@testable import habit_tracker

struct HabitStreakTests {
  private let todayKey = "2026-07-31"

  @Test func requiresThirtyEligibleDays() {
    let length = streakLength(
      completedEntries: entries(count: 27)
    )

    #expect(length == nil)
  }

  @Test func twoExceptionsAllowTwentyEightCompletionsToQualify() {
    let length = streakLength(
      completedEntries: entries(count: 28)
    )

    #expect(length == 30)
  }

  @Test func exceptionAllowanceIncreasesAtMilestones() {
    #expect(streakLength(
      completedEntries: entries(count: 47)
    ) == 50)
    #expect(streakLength(
      completedEntries: entries(count: 66)
    ) == 70)
    #expect(streakLength(
      completedEntries: entries(count: 85)
    ) == 90)
  }

  @Test func hiddenDaysAreNeitherCompletionsNorExceptions() {
    let hiddenKey = dateKey(daysBeforeToday: 27)
    let olderCompletion = HabitStreak.Entry(
      dateKey: dateKey(daysBeforeToday: 30),
      state: .completed,
      updatedAt: .distantPast
    )
    let completedEntries = entries(count: 27)
      + [olderCompletion]

    #expect(streakLength(
      completedEntries: completedEntries,
      hiddenDateKeys: [hiddenKey]
    ) == 30)
    #expect(streakLength(
      completedEntries: completedEntries
    ) == nil)
  }

  @Test func skippedDaysAreNeitherCompletionsNorExceptions() {
    let skipped = HabitStreak.Entry(
      dateKey: dateKey(daysBeforeToday: 27),
      state: .skipped,
      updatedAt: .now
    )
    let olderCompletion = HabitStreak.Entry(
      dateKey: dateKey(daysBeforeToday: 30),
      state: .completed,
      updatedAt: .distantPast
    )
    let completedEntries = entries(count: 27)
      + [olderCompletion]

    #expect(streakLength(
      completedEntries: completedEntries + [skipped]
    ) == 30)
    #expect(streakLength(
      completedEntries: completedEntries
    ) == nil)
  }

  @Test func skippingADayDoesNotCountAsACompletion() {
    let yesterdayKey = DayBoundary.yesterdayKey(
      from: todayKey
    )
    let skippedToday = HabitStreak.Entry(
      dateKey: todayKey,
      state: .skipped,
      updatedAt: .now
    )
    let completedEntries = entries(
      count: 29,
      endingAt: yesterdayKey
    )

    // The skip neither extends nor shortens what the
    // completions alone qualify for.
    #expect(streakLength(
      completedEntries: completedEntries + [skippedToday]
    ) == streakLength(
      completedEntries: completedEntries
    ))
  }

  @Test func uncheckedCurrentDayDoesNotCountAsException() {
    let yesterdayKey = DayBoundary.yesterdayKey(from: todayKey)
    let uncheckedToday = HabitStreak.Entry(
      dateKey: todayKey,
      state: .unmarked,
      updatedAt: .now
    )
    let completedEntries = entries(
      count: 28,
      endingAt: yesterdayKey
    ) + [uncheckedToday]

    #expect(streakLength(
      completedEntries: completedEntries
    ) == 30)
  }

  @Test func mostRecentlyUpdatedDuplicateDeterminesCompletion() {
    let yesterdayKey = DayBoundary.yesterdayKey(from: todayKey)
    let completedEntries = entries(
      count: 28,
      endingAt: yesterdayKey
    ) + [
      HabitStreak.Entry(
        dateKey: todayKey,
        state: .completed,
        updatedAt: Date(timeIntervalSince1970: 1)
      ),
      HabitStreak.Entry(
        dateKey: todayKey,
        state: .unmarked,
        updatedAt: Date(timeIntervalSince1970: 2)
      ),
    ]

    #expect(streakLength(
      completedEntries: completedEntries
    ) == 30)
  }

  @Test func sixthExceptionResetsAnOldStreak() {
    let beforeSixMisses = dateKey(daysBeforeToday: 7)
    let oldCompletions = entries(
      count: 100,
      endingAt: beforeSixMisses
    )

    #expect(streakLength(
      completedEntries: oldCompletions
    ) == nil)
  }

  @Test func titleBackgroundUsesExponentialInterpolation() throws {
    let start = try #require(
      HabitStreak.titleBackgroundGreenOpacity(for: 30)
    )
    let midpoint = try #require(
      HabitStreak.titleBackgroundGreenOpacity(for: 60)
    )
    let end = try #require(
      HabitStreak.titleBackgroundGreenOpacity(for: 90)
    )

    #expect(abs(start - 0.12) < 0.000_001)
    #expect(midpoint < (start + end) / 2)
    #expect(abs(end - 0.35) < 0.000_001)
    #expect(
      HabitStreak.titleBackgroundGreenOpacity(for: 29) == nil
    )
    #expect(
      HabitStreak.titleBackgroundGreenOpacity(for: 120) == end
    )
  }

  @Test func goalTitleContrastPassesWCAGAAAtEveryStage() {
    for colorScheme in [ColorScheme.light, .dark] {
      var environment = EnvironmentValues()
      environment.colorScheme = colorScheme

      let base = resolved(
        appBackgroundColor,
        in: environment
      )
      let green = resolved(.green, in: environment)
      let primary = resolved(.primary, in: environment)

      for qualifyingLength in 0...120 {
        let greenOpacity = HabitStreak
          .titleBackgroundGreenOpacity(
            for: qualifyingLength
          ) ?? 0
        let background = green.composited(
          over: base,
          opacity: greenOpacity
        )
        let displayedText = primary.composited(
          over: background
        )
        let contrast = contrastRatio(
          displayedText,
          background
        )

        #expect(
          contrast >= 4.5,
          Comment(
            rawValue: "\(colorScheme) mode at day "
              + "\(qualifyingLength) has only "
              + "\(contrast):1 contrast"
          )
        )
      }
    }
  }

  private struct ResolvedColor {
    let red: Double
    let green: Double
    let blue: Double
    let opacity: Double

    func composited(
      over background: ResolvedColor,
      opacity additionalOpacity: Double = 1
    ) -> ResolvedColor {
      let alpha = opacity * additionalOpacity
      return ResolvedColor(
        red: red * alpha + background.red * (1 - alpha),
        green: green * alpha
          + background.green * (1 - alpha),
        blue: blue * alpha
          + background.blue * (1 - alpha),
        opacity: 1
      )
    }
  }

  private var appBackgroundColor: Color {
    #if canImport(AppKit)
    Color(nsColor: .windowBackgroundColor)
    #elseif canImport(UIKit)
    Color(uiColor: .systemBackground)
    #endif
  }

  private func resolved(
    _ color: Color,
    in environment: EnvironmentValues
  ) -> ResolvedColor {
    let resolved = color.resolve(in: environment)
    return ResolvedColor(
      red: Double(resolved.red),
      green: Double(resolved.green),
      blue: Double(resolved.blue),
      opacity: Double(resolved.opacity)
    )
  }

  private func contrastRatio(
    _ first: ResolvedColor,
    _ second: ResolvedColor
  ) -> Double {
    let lighter = max(luminance(first), luminance(second))
    let darker = min(luminance(first), luminance(second))
    return (lighter + 0.05) / (darker + 0.05)
  }

  private func luminance(_ color: ResolvedColor) -> Double {
    0.2126 * linearComponent(color.red)
      + 0.7152 * linearComponent(color.green)
      + 0.0722 * linearComponent(color.blue)
  }

  private func linearComponent(_ component: Double) -> Double {
    component <= 0.04045
      ? component / 12.92
      : pow((component + 0.055) / 1.055, 2.4)
  }

  private func streakLength(
    completedEntries: [HabitStreak.Entry],
    hiddenDateKeys: Set<String> = []
  ) -> Int? {
    HabitStreak.currentQualifyingLength(
      entries: completedEntries,
      hiddenDateKeys: hiddenDateKeys,
      effectiveTodayKey: todayKey
    )
  }

  private func entries(
    count: Int,
    endingAt endKey: String? = nil
  ) -> [HabitStreak.Entry] {
    var dateKey = endKey ?? todayKey
    return (0..<count).map { _ in
      defer {
        dateKey = DayBoundary.yesterdayKey(from: dateKey)
      }
      return HabitStreak.Entry(
        dateKey: dateKey,
        state: .completed,
        updatedAt: .distantPast
      )
    }
  }

  private func dateKey(daysBeforeToday: Int) -> String {
    var dateKey = todayKey
    for _ in 0..<daysBeforeToday {
      dateKey = DayBoundary.yesterdayKey(from: dateKey)
    }
    return dateKey
  }
}

struct DayBoundaryTests {
  @Test func dateKeyReturnsCorrectFormat() {
    let key = DayBoundary.dateKey()
    #expect(key.count == 10) // "yyyy-MM-dd"
    #expect(key.contains("-"))
  }

  @Test func tomorrowKeyIsOneDayAhead() {
    let today = "2026-03-17"
    let tomorrow = DayBoundary.tomorrowKey(from: today)
    #expect(tomorrow == "2026-03-18")
  }

  @Test func yesterdayKeyIsOneDayBehind() {
    let today = "2026-03-17"
    let yesterday = DayBoundary.yesterdayKey(from: today)
    #expect(yesterday == "2026-03-16")
  }

  @Test func fourAMBoundaryBefore() {
    let cal = Calendar.current
    var c = cal.dateComponents(
      [.year, .month, .day], from: Date()
    )
    c.hour = 3; c.minute = 30
    let at3AM = cal.date(from: c)!
    let key = DayBoundary.dateKey(for: at3AM)
    let yesterday = DayBoundary.yesterdayKey(
      from: DayBoundary.dateKey(for: cal.date(from: {
        var d = c; d.hour = 12; return d
      }())!)
    )
    #expect(key == yesterday)
  }

  @Test func fourAMBoundaryAfter() {
    let cal = Calendar.current
    var c = cal.dateComponents(
      [.year, .month, .day], from: Date()
    )
    c.hour = 4; c.minute = 1
    let at4AM = cal.date(from: c)!
    let key4 = DayBoundary.dateKey(for: at4AM)
    c.hour = 12
    let keyNoon = DayBoundary.dateKey(
      for: cal.date(from: c)!
    )
    #expect(key4 == keyNoon)
  }

  @Test func displayStringFormat() {
    let display = DayBoundary.displayString(for: "2026-03-17")
    #expect(display.contains("Tue"))
    #expect(display.contains("3/17"))
  }

  @Test func roundTrip() {
    let key = "2026-03-17"
    let next = DayBoundary.tomorrowKey(from: key)
    let back = DayBoundary.yesterdayKey(from: next)
    #expect(back == key)
  }

}

struct DayColumnLayoutTests {
  private let todayKey = "2026-03-17"

  @Test func futureDaysRemainToTheRightOfToday() {
    let layout = DayColumnLayout(
      visibleDateKeys: [
        "2026-03-18",
        "2026-03-16",
        "2026-03-17",
        "2026-03-19",
      ],
      todayKey: todayKey
    )

    #expect(layout.pastDateKeys == ["2026-03-16"])
    #expect(
      layout.currentAndFutureDateKeys == [
        "2026-03-17",
        "2026-03-18",
        "2026-03-19",
      ]
    )
  }

  @Test func todayIsPresentWhileItsDayRecordLoads() {
    let layout = DayColumnLayout(
      visibleDateKeys: ["2026-03-16"],
      todayKey: todayKey
    )

    #expect(layout.currentAndFutureDateKeys == [todayKey])
  }

  @Test func onlyTodayAndYesterdayAllowImmediateTaps() {
    let layout = DayColumnLayout(
      visibleDateKeys: [
        "2026-03-15",
        "2026-03-16",
        "2026-03-17",
        "2026-03-18",
      ],
      todayKey: todayKey
    )

    #expect(layout.allowsTapToComplete(for: "2026-03-16"))
    #expect(layout.allowsTapToComplete(for: "2026-03-17"))
    #expect(!layout.allowsTapToComplete(for: "2026-03-15"))
    #expect(!layout.allowsTapToComplete(for: "2026-03-18"))
  }
}

struct CompletionModelTests {
  private func makeCompletion() -> Completion {
    Completion(
      dateKey: "2026-07-20",
      goal: Goal(name: "Exercise", sortOrder: 0)
    )
  }

  @Test func stateRoundTripsThroughStoredValues() {
    let completion = makeCompletion()
    #expect(completion.state == .completed)

    completion.state = .skipped
    #expect(completion.state == .skipped)

    completion.state = .unmarked
    #expect(completion.state == .unmarked)

    completion.state = .completed
    #expect(completion.state == .completed)
  }

  @Test func legacyFlagMirrorsEveryStateChange() {
    let completion = makeCompletion()
    #expect(completion.isCompleted)

    // Older clients only understand isCompleted, so a skip
    // has to read as "not completed" to them.
    completion.state = .skipped
    #expect(completion.isCompleted == false)

    completion.state = .completed
    #expect(completion.isCompleted)

    completion.state = .unmarked
    #expect(completion.isCompleted == false)
  }

  @Test func recordsWithoutAStateFallBackToTheLegacyFlag() {
    // How rows written before skipping existed, and records
    // synced from a client that predates it, arrive.
    let completion = makeCompletion()
    completion.stateRawValue = ""

    completion.isCompleted = true
    #expect(completion.state == .completed)

    completion.isCompleted = false
    #expect(completion.state == .unmarked)
  }

  @Test func unrecognizedStateFallsBackToTheLegacyFlag() {
    let completion = makeCompletion()
    completion.stateRawValue = "somethingNewerWroteThis"
    completion.isCompleted = true

    #expect(completion.state == .completed)
  }
}

struct GoalModelTests {
  @Test func renameTracksHistory() {
    let goal = Goal(name: "A", sortOrder: 0)
    goal.rename(to: "B")
    #expect(goal.name == "B")
    #expect(goal.nameHistory.count == 1)
    #expect(goal.nameHistory[0].oldName == "A")
  }

  @Test func multipleRenamesAccumulate() {
    let goal = Goal(name: "A", sortOrder: 0)
    goal.rename(to: "B")
    goal.rename(to: "C")
    #expect(goal.nameHistory.count == 2)
    #expect(goal.nameHistory.map(\.oldName) == ["A", "B"])
  }

  @Test func emptyNameHistoryByDefault() {
    let goal = Goal(name: "Test", sortOrder: 0)
    #expect(goal.nameHistory.isEmpty)
    #expect(goal.nameHistoryJSON == "[]")
  }
}

struct DayModelTests {
  @Test func intentionDefaultsToEmpty() {
    let day = Day(dateKey: "2026-07-28")

    #expect(day.intentionText.isEmpty)
    #expect(day.intentionUpdatedAt == nil)
  }

  @Test func intentionCanBeCreatedWithDay() {
    let day = Day(
      dateKey: "2026-07-28",
      intentionText: "Ship CloudKit sync"
    )

    #expect(day.intentionText == "Ship CloudKit sync")
    #expect(day.intentionUpdatedAt != nil)
  }

  @Test func persistentSchemaContainsHabitEntities() throws {
    let model = try #require(
      NSManagedObjectModel.makeManagedObjectModel(
        for: [
          Goal.self,
          Completion.self,
          Day.self,
        ]
      )
    )

    let entityNames = Set(
      model.entities.compactMap(\.name)
    )
    #expect(
      entityNames == [
        "Goal",
        "Completion",
        "Day",
      ]
    )
  }

  @Test @MainActor
  func migrationMergesIntentionsIntoDays() throws {
    let migrationDirectory = FileManager.default
      .temporaryDirectory
      .appending(
        path: "HabitMigration-\(UUID().uuidString)",
        directoryHint: .isDirectory
      )
    try FileManager.default.createDirectory(
      at: migrationDirectory,
      withIntermediateDirectories: true
    )
    defer {
      try? FileManager.default.removeItem(
        at: migrationDirectory
      )
    }

    let storeURL = migrationDirectory.appending(
      path: "migration.store"
    )
    let dateKey = "2026-07-28"
    let intentionText = "Preserve this intention"

    try autoreleasepool {
      let schema = Schema(
        versionedSchema: HabitSchemaV1.self
      )
      let configuration = ModelConfiguration(
        "MigrationTestV1",
        schema: schema,
        url: storeURL,
        cloudKitDatabase: .none
      )
      let container = try ModelContainer(
        for: schema,
        configurations: [configuration]
      )
      let goal = HabitSchemaV1.Goal(
        name: "Exercise",
        sortOrder: 0
      )
      goal.isDeleted = true
      goal.nameHistoryJSON =
        """
        [{"oldName":"Movement","changedAt":0}]
        """
      let completion = HabitSchemaV1.Completion(
        dateKey: dateKey,
        goal: goal
      )
      completion.isCompleted = false
      let completedCompletion = HabitSchemaV1.Completion(
        dateKey: "2026-07-27",
        goal: goal
      )
      completedCompletion.isCompleted = true
      let day = HabitSchemaV1.Day(dateKey: dateKey)
      day.isHidden = true
      container.mainContext.insert(
        day
      )
      container.mainContext.insert(
        HabitSchemaV1.Intention(
          dateKey: dateKey,
          text: intentionText
        )
      )
      container.mainContext.insert(goal)
      container.mainContext.insert(
        completion
      )
      container.mainContext.insert(
        completedCompletion
      )
      try container.mainContext.save()
    }

    try autoreleasepool {
      let schema = Schema(
        versionedSchema: HabitSchemaV5.self
      )
      let configuration = ModelConfiguration(
        "MigrationTestV5",
        schema: schema,
        url: storeURL,
        cloudKitDatabase: .none
      )
      let container = try ModelContainer(
        for: schema,
        migrationPlan: HabitSchemaMigrationPlan.self,
        configurations: [configuration]
      )
      let days = try container.mainContext.fetch(
        FetchDescriptor<Day>()
      )
      let goals = try container.mainContext.fetch(
        FetchDescriptor<Goal>()
      )
      let completions = try container.mainContext.fetch(
        FetchDescriptor<Completion>()
      )

      #expect(days.count == 1)
      #expect(days.first?.intentionText == intentionText)
      #expect(days.first?.intentionUpdatedAt != nil)
      #expect(days.first?.isHidden == true)
      #expect(goals.map(\.name) == ["Exercise"])
      #expect(goals.first?.isArchived == true)
      #expect(
        goals.first?.nameHistoryJSON
          == """
          [{"oldName":"Movement","changedAt":0}]
          """
      )
      let byDateKey = Dictionary(
        uniqueKeysWithValues: completions.map {
          ($0.dateKey, $0)
        }
      )
      let migrated = try #require(byDateKey[dateKey])
      let migratedCompleted = try #require(
        byDateKey["2026-07-27"]
      )

      #expect(completions.count == 2)
      #expect(migrated.isCompleted == false)
      #expect(migrated.goal?.name == "Exercise")

      // Migrating stamps a state onto every existing row, so
      // an empty stateRawValue afterwards means the record
      // came from a client predating version five.
      #expect(migrated.state == .unmarked)
      #expect(migrated.stateRawValue == "unmarked")
      #expect(migratedCompleted.state == .completed)
      #expect(migratedCompleted.stateRawValue == "completed")
    }
  }

  @Test
  func unchangedEntityHashesRemainStable() throws {
    let versionOne = try #require(
      NSManagedObjectModel.makeManagedObjectModel(
        for: HabitSchemaV1.models
      )
    )
    let versionTwo = try #require(
      NSManagedObjectModel.makeManagedObjectModel(
        for: HabitSchemaV2.models
      )
    )
    let versionThree = try #require(
      NSManagedObjectModel.makeManagedObjectModel(
        for: HabitSchemaV3.models
      )
    )
    let versionFour = try #require(
      NSManagedObjectModel.makeManagedObjectModel(
        for: HabitSchemaV4.models
      )
    )
    let versionFive = try #require(
      NSManagedObjectModel.makeManagedObjectModel(
        for: HabitSchemaV5.models
      )
    )

    for entityName in ["Goal", "Completion"] {
      #expect(
        versionOne.entityVersionHashesByName[entityName]
          == versionTwo.entityVersionHashesByName[entityName]
      )
      #expect(
        versionTwo.entityVersionHashesByName[entityName]
          == versionThree.entityVersionHashesByName[entityName]
      )
    }
    #expect(
      versionTwo.entityVersionHashesByName["Day"]
        == versionThree.entityVersionHashesByName["Day"]
    )
    // Freezing version four must not have disturbed the
    // entities it shares with version three.
    #expect(
      versionThree.entityVersionHashesByName["Completion"]
        == versionFour.entityVersionHashesByName["Completion"]
    )
    #expect(
      versionThree.entityVersionHashesByName["Day"]
        == versionFour.entityVersionHashesByName["Day"]
    )
    // Version five only adds Completion.stateRawValue.
    for entityName in ["Goal", "Day"] {
      #expect(
        versionFour.entityVersionHashesByName[entityName]
          == versionFive.entityVersionHashesByName[entityName]
      )
    }
    #expect(
      versionFour.entityVersionHashesByName["Completion"]
        != versionFive.entityVersionHashesByName["Completion"]
    )
  }
}

struct HabitDataExportTests {
  @Test @MainActor
  func exportFiltersDateScopedRecords() throws {
    let goal = Goal(name: "Exercise", sortOrder: 0)
    let inRangeDay = Day(
      dateKey: "2026-07-20",
      intentionText: "Run"
    )
    let outOfRangeDay = Day(dateKey: "2026-07-21")
    let inRangeCompletion = Completion(
      dateKey: "2026-07-20",
      goal: goal
    )
    let outOfRangeCompletion = Completion(
      dateKey: "2026-07-21",
      goal: goal
    )

    let export = HabitDataExport.make(
      goals: [goal],
      days: [inRangeDay, outOfRangeDay],
      completions: [
        inRangeCompletion,
        outOfRangeCompletion,
      ],
      startDateKey: "2026-07-20",
      endDateKey: "2026-07-20"
    )

    #expect(export.formatVersion == 1)
    #expect(export.modelSchemaVersion == "3.0.0")
    #expect(export.goals.map(\.name) == ["Exercise"])
    #expect(export.days.map(\.dateKey) == ["2026-07-20"])
    #expect(
      export.completions.map(\.dateKey)
        == ["2026-07-20"]
    )
    #expect(export.completions.first?.goalID == goal.id)
    #expect(
      export.completions.first?.state == .completed
    )
  }

  @Test @MainActor
  func exportJSONRoundTrips() throws {
    let goal = Goal(name: "Read", sortOrder: 0)
    let export = HabitDataExport.make(
      goals: [goal],
      days: [Day(dateKey: "2026-07-20")],
      completions: [],
      startDateKey: "2026-07-20",
      endDateKey: "2026-07-20"
    )

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(
      HabitDataExport.self,
      from: export.encodedJSON()
    )

    #expect(decoded.formatVersion == 1)
    #expect(decoded.modelSchemaVersion == "3.0.0")
    #expect(decoded.goals.first?.id == goal.id)
    #expect(decoded.dateRange.start == "2026-07-20")
    #expect(decoded.dateRange.end == "2026-07-20")
  }

  @Test @MainActor
  func weeklyBackupsAreImmutableAndRateLimited() throws {
    let directory = FileManager.default
      .temporaryDirectory
      .appending(
        path: "HabitBackup-\(UUID().uuidString)",
        directoryHint: .isDirectory
      )
    try FileManager.default.createDirectory(
      at: directory,
      withIntermediateDirectories: true
    )
    defer {
      try? FileManager.default.removeItem(at: directory)
    }

    let now = Date.now
    let export = HabitDataExport.make(
      goals: [],
      days: [Day(dateKey: "2026-07-20")],
      completions: [],
      startDateKey: "2026-07-20",
      endDateKey: "2026-07-20",
      exportedAt: now
    )

    try HabitBackupStore.saveWeeklyIfNeeded(
      export,
      now: now,
      directoryURL: directory
    )
    try HabitBackupStore.saveWeeklyIfNeeded(
      export,
      now: now.addingTimeInterval(24 * 60 * 60),
      directoryURL: directory
    )
    #expect(
      try HabitBackupStore.backups(
        directoryURL: directory
      ).count == 1
    )

    try HabitBackupStore.saveWeeklyIfNeeded(
      export,
      now: now.addingTimeInterval(8 * 24 * 60 * 60),
      directoryURL: directory
    )
    #expect(
      try HabitBackupStore.backups(
        directoryURL: directory
      ).count == 2
    )
  }
}

struct DayDeletionTests {
  @Test @MainActor
  func hidesEveryDuplicateAndMovesSelection() {
    let earlierDay = Day(dateKey: "2026-07-19")
    let duplicateA = Day(dateKey: "2026-07-20")
    let duplicateB = Day(dateKey: "2026-07-20")
    let laterDay = Day(dateKey: "2026-07-21")

    let outcome = DayDeletion.hide(
      dateKey: "2026-07-20",
      in: [
        earlierDay,
        duplicateA,
        duplicateB,
        laterDay,
      ],
      selectedDateKey: "2026-07-20",
      effectiveTodayKey: "2026-07-21"
    )

    #expect(duplicateA.isHidden)
    #expect(duplicateB.isHidden)
    #expect(!earlierDay.isHidden)
    #expect(!laterDay.isHidden)
    #expect(outcome.selectedDateKey == "2026-07-19")
    #expect(!outcome.shouldEnsureTodayExists)
  }

  @Test @MainActor
  func deletingEffectiveTodayRequestsRestoration() {
    let day = Day(dateKey: "2026-07-20")

    let outcome = DayDeletion.hide(
      dateKey: day.dateKey,
      in: [day],
      selectedDateKey: day.dateKey,
      effectiveTodayKey: day.dateKey
    )

    #expect(day.isHidden)
    #expect(outcome.shouldEnsureTodayExists)
  }
}

struct GoalArchiveTests {
  @Test @MainActor
  func archivingPersistsWithoutAutosave() throws {
    let goal = Goal(name: "Exercise", sortOrder: 0)
    let container = try makeContainer(goals: [goal])
    let context = container.mainContext

    try GoalArchive.archive(goal, in: context)

    #expect(goal.isArchived)
    #expect(!context.hasChanges)

    let verificationContext = ModelContext(container)
    let persistedGoals = try verificationContext.fetch(
      FetchDescriptor<Goal>()
    )
    #expect(persistedGoals.first?.isArchived == true)
  }

  @Test @MainActor
  func restoringAppendsGoalBelowActiveGoals() throws {
    let first = Goal(name: "Exercise", sortOrder: 0)
    let second = Goal(name: "Read", sortOrder: 5)
    let archived = Goal(name: "Meditate", sortOrder: 3)
    archived.archivedAt = Date()
    let container = try makeContainer(
      goals: [first, second, archived]
    )

    try GoalArchive.restore(
      archived,
      activeGoals: [first, second],
      in: container.mainContext
    )

    #expect(!archived.isArchived)
    #expect(first.sortOrder == 0)
    #expect(second.sortOrder == 1)
    #expect(archived.sortOrder == 2)
  }

  @Test @MainActor
  func restoringKeepsCompletionHistory() throws {
    let goal = Goal(name: "Exercise", sortOrder: 0)
    let completion = Completion(
      dateKey: "2026-07-20",
      goal: goal
    )
    goal.completions = [completion]
    let container = try makeContainer(goals: [goal])
    let context = container.mainContext
    try GoalArchive.archive(goal, in: context)

    try GoalArchive.restore(
      goal,
      activeGoals: [],
      in: context
    )

    #expect(!goal.isArchived)
    #expect(goal.sortOrder == 0)
    #expect(goal.completions?.count == 1)
    #expect(
      goal.completions?.first?.dateKey == "2026-07-20"
    )
  }

  @Test @MainActor
  func restoringSuccessiveGoalsDoesNotCollide() throws {
    let active = Goal(name: "Exercise", sortOrder: 0)
    let first = Goal(name: "Read", sortOrder: 0)
    let second = Goal(name: "Meditate", sortOrder: 0)
    first.archivedAt = Date()
    second.archivedAt = Date()
    let container = try makeContainer(
      goals: [active, first, second]
    )
    let context = container.mainContext

    try GoalArchive.restore(
      first,
      activeGoals: [active],
      in: context
    )
    try GoalArchive.restore(
      second,
      activeGoals: [active, first],
      in: context
    )

    #expect(
      [active, first, second].map(\.sortOrder) == [0, 1, 2]
    )
  }

  @Test @MainActor
  func displayOrderSortsNamedGoalsAheadOfUntitled() {
    let read = Goal(name: "read", sortOrder: 0)
    let exercise = Goal(name: "Exercise", sortOrder: 1)
    let untitled = Goal(name: "", sortOrder: 2)

    let ordered = GoalArchive.displayOrder(
      archived: [untitled, read, exercise]
    )

    #expect(ordered.map(\.name) == ["Exercise", "read", ""])
  }

  @MainActor
  private func makeContainer(
    goals: [Goal]
  ) throws -> ModelContainer {
    let configuration = ModelConfiguration(
      isStoredInMemoryOnly: true,
      cloudKitDatabase: .none
    )
    let container = try ModelContainer(
      for: Goal.self, Completion.self, Day.self,
      configurations: configuration
    )
    let context = container.mainContext
    context.autosaveEnabled = false
    for goal in goals {
      context.insert(goal)
    }
    try context.save()
    return container
  }
}

struct MigrationStoreBackupTests {
  @Test
  func snapshotCopiesStoreFamilyOnlyOnce() throws {
    let directory = FileManager.default
      .temporaryDirectory
      .appending(
        path: "MigrationSnapshot-\(UUID().uuidString)",
        directoryHint: .isDirectory
      )
    let sourceDirectory = directory.appending(
      path: "Source",
      directoryHint: .isDirectory
    )
    let backupDirectory = directory.appending(
      path: "Backups",
      directoryHint: .isDirectory
    )
    try FileManager.default.createDirectory(
      at: sourceDirectory,
      withIntermediateDirectories: true
    )
    defer {
      try? FileManager.default.removeItem(at: directory)
    }

    let storeURL = sourceDirectory.appending(
      path: "default.store"
    )
    let originalStore = Data("original".utf8)
    let originalWAL = Data("wal".utf8)
    try originalStore.write(to: storeURL)
    try originalWAL.write(
      to: URL(filePath: storeURL.path + "-wal")
    )

    let createdSnapshot =
      try MigrationStoreBackup.createIfNeeded(
        storeURL: storeURL,
        modelTypes: HabitSchemaV4.models,
        backupRootURL: backupDirectory
      )
    let snapshot = try #require(createdSnapshot)
    #expect(
      try Data(
        contentsOf: snapshot.appending(
          path: "default.store"
        )
      ) == originalStore
    )
    #expect(
      try Data(
        contentsOf: snapshot.appending(
          path: "default.store-wal"
        )
      ) == originalWAL
    )

    try Data("changed".utf8).write(to: storeURL)
    let existingSnapshot =
      try MigrationStoreBackup.createIfNeeded(
      storeURL: storeURL,
      modelTypes: HabitSchemaV4.models,
      backupRootURL: backupDirectory
    )
    let secondSnapshot = try #require(existingSnapshot)

    #expect(secondSnapshot == snapshot)
    #expect(
      try Data(
        contentsOf: secondSnapshot.appending(
          path: "default.store"
        )
      ) == originalStore
    )

    // A new target schema is a new migration, so it takes
    // its own snapshot of the store as it stands right
    // before that migration runs.
    let upgradeSnapshot = try #require(
      try MigrationStoreBackup.createIfNeeded(
        storeURL: storeURL,
        modelTypes: HabitSchemaV5.models,
        backupRootURL: backupDirectory
      )
    )

    #expect(upgradeSnapshot != snapshot)
    #expect(
      try Data(
        contentsOf: upgradeSnapshot.appending(
          path: "default.store"
        )
      ) == Data("changed".utf8)
    )
  }
}

struct CloudSyncMonitorTests {
  @Test @MainActor
  func latestSuccessfulEventClearsEarlierFailure() throws {
    let suiteName = "CloudSyncMonitorTests-\(UUID().uuidString)"
    let defaults = try #require(
      UserDefaults(suiteName: suiteName)
    )
    defer {
      defaults.removePersistentDomain(forName: suiteName)
    }
    let now = Date.now
    let events = [
      CloudSyncEventRecord(
        id: UUID(),
        kind: .importData,
        startedAt: now,
        endedAt: now,
        succeeded: true,
        errorDetails: nil
      ),
      CloudSyncEventRecord(
        id: UUID(),
        kind: .importData,
        startedAt: now.addingTimeInterval(-60),
        endedAt: now.addingTimeInterval(-59),
        succeeded: false,
        errorDetails: "Network unavailable"
      ),
    ]
    defaults.set(
      try JSONEncoder().encode(events),
      forKey: "cloudSync.recentEvents.v1"
    )

    let monitor = CloudSyncMonitor(
      defaults: defaults,
      observeEvents: false
    )

    #expect(!monitor.needsAttention)
  }

  @Test
  func errorFormatterIncludesUnderlyingError() {
    let underlying = NSError(
      domain: "CKErrorDomain",
      code: 4,
      userInfo: [
        NSLocalizedDescriptionKey: "Network unavailable",
      ]
    )
    let outer = NSError(
      domain: "NSCocoaErrorDomain",
      code: 134400,
      userInfo: [
        NSLocalizedDescriptionKey: "Cloud import failed",
        NSUnderlyingErrorKey: underlying,
      ]
    )

    let details = CloudSyncErrorFormatter.details(for: outer)

    #expect(details.contains("NSCocoaErrorDomain (134400)"))
    #expect(details.contains("CKErrorDomain (4)"))
    #expect(details.contains("Network unavailable"))
  }

  @Test
  func errorFormatterIncludesBridgedPartialErrors() {
    let recordID = CKRecord.ID(recordName: "more-recent-ipad-data")
    let rejectedRecord = NSError(
      domain: CKError.errorDomain,
      code: CKError.serverRejectedRequest.rawValue,
      userInfo: [
        NSLocalizedDescriptionKey: "Field is not in the production schema",
      ]
    )
    let partialErrors = NSDictionary(
      object: rejectedRecord,
      forKey: recordID
    )
    let outer = NSError(
      domain: CKError.errorDomain,
      code: CKError.partialFailure.rawValue,
      userInfo: [
        CKPartialErrorsByItemIDKey: partialErrors,
      ]
    )

    let details = CloudSyncErrorFormatter.details(for: outer)

    #expect(details.contains("more-recent-ipad-data"))
    #expect(details.contains("CKErrorDomain (15)"))
    #expect(details.contains("Field is not in the production schema"))
  }
}
