import CoreData
import Foundation
import SwiftData
import Testing
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
      isCompleted: true,
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

  @Test func uncheckedCurrentDayDoesNotCountAsException() {
    let yesterdayKey = DayBoundary.yesterdayKey(from: todayKey)
    let uncheckedToday = HabitStreak.Entry(
      dateKey: todayKey,
      isCompleted: false,
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
        isCompleted: true,
        updatedAt: Date(timeIntervalSince1970: 1)
      ),
      HabitStreak.Entry(
        dateKey: todayKey,
        isCompleted: false,
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

  @Test func titleColorUsesExponentialInterpolation() throws {
    let start = try #require(
      HabitStreak.titleGreenOpacity(for: 30)
    )
    let midpoint = try #require(
      HabitStreak.titleGreenOpacity(for: 60)
    )
    let end = try #require(
      HabitStreak.titleGreenOpacity(for: 90)
    )

    #expect(abs(start - 0.12) < 0.000_001)
    #expect(midpoint < (start + end) / 2)
    #expect(abs(end - 0.35) < 0.000_001)
    #expect(HabitStreak.titleGreenOpacity(for: 29) == nil)
    #expect(HabitStreak.titleGreenOpacity(for: 120) == end)
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
        isCompleted: true,
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

  @Test func effectiveTodayRestoresVisibleFutureDay() {
    let effective = DayBoundary.effectiveTodayKey(
      calendarTodayKey: "2026-03-17",
      visibleDateKeys: [
        "2026-03-16",
        "2026-03-17",
        "2026-03-18",
      ]
    )
    #expect(effective == "2026-03-18")
  }

  @Test func effectiveTodayIgnoresPastDays() {
    let effective = DayBoundary.effectiveTodayKey(
      calendarTodayKey: "2026-03-17",
      visibleDateKeys: [
        "2026-03-15",
        "2026-03-16",
      ]
    )
    #expect(effective == "2026-03-17")
  }

  @Test func effectiveTodayUsesLatestVisibleFutureDay() {
    let effective = DayBoundary.effectiveTodayKey(
      calendarTodayKey: "2026-03-17",
      visibleDateKeys: [
        "2026-03-19",
        "2026-03-18",
      ]
    )
    #expect(effective == "2026-03-19")
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
      try container.mainContext.save()
    }

    try autoreleasepool {
      let schema = Schema(
        versionedSchema: HabitSchemaV4.self
      )
      let configuration = ModelConfiguration(
        "MigrationTestV4",
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
      #expect(completions.count == 1)
      #expect(completions.first?.isCompleted == false)
      #expect(completions.first?.goal?.name == "Exercise")
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
  }
}
