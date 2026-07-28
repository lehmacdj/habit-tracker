import CoreData
import Foundation
import SwiftData
import Testing
@testable import habit_tracker

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
      container.mainContext.insert(
        HabitSchemaV1.Day(dateKey: dateKey)
      )
      container.mainContext.insert(
        HabitSchemaV1.Intention(
          dateKey: dateKey,
          text: intentionText
        )
      )
      container.mainContext.insert(goal)
      container.mainContext.insert(
        HabitSchemaV1.Completion(
          dateKey: dateKey,
          goal: goal
        )
      )
      try container.mainContext.save()
    }

    try autoreleasepool {
      let schema = Schema(
        versionedSchema: HabitSchemaV3.self
      )
      let configuration = ModelConfiguration(
        "MigrationTestV3",
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
      #expect(goals.map(\.name) == ["Exercise"])
      #expect(completions.count == 1)
      #expect(completions.first?.goal?.name == "Exercise")
    }
  }
}
