import Foundation
import SwiftData
import Testing
@testable import habit_tracker

struct GridViewportTests {
  @Test func boundsWorkForEmptySectionsAndOverscroll() {
    #expect(GridViewport(offset: -100, width: 393)
      .range(count: 0, origin: 0) == 0..<0)
    #expect(GridViewport(offset: -100, width: 393)
      .range(count: 60, origin: 0).lowerBound == 0)
    #expect(GridViewport(offset: 10_000, width: 393)
      .range(count: 60, origin: 0) == 60..<60)
  }

  @Test func everyVisibleDateIsCoveredWithBoundedMaterialization() {
    // Sweep across long history, the wider Goals column, and future days.
    let pastCount = 179
    let futureOrigin = CGFloat(pastCount) * 48 + 160
    for offset in stride(from: CGFloat(0), through: 9_000, by: 17) {
      let viewport = GridViewport(offset: offset, width: 393)
      for (count, origin) in [(pastCount, CGFloat(0)), (4, futureOrigin)] {
        let range = viewport.range(count: count, origin: origin)
        // Nine screen columns, up to eight from bucket rounding,
        // and eight prefetched columns, independent of history size.
        #expect(range.count <= 25)
        for index in 0..<count {
          let left = origin + CGFloat(index) * 48
          if left < offset + 393 && left + 48 > offset {
            #expect(range.contains(index))
          }
        }
        let leading = CGFloat(range.lowerBound) * 48
        let trailing = CGFloat(count - range.upperBound) * 48
        #expect(leading + CGFloat(range.count) * 48 + trailing
          == CGFloat(count) * 48)
      }
    }
  }

  @Test func windowAccountsForLeftFillAndWideContainers() {
    let viewport = GridViewport(offset: 0, width: 1_024)
    #expect(viewport.range(count: 2, origin: 720) == 0..<2)
    #expect(viewport.range(count: 1, origin: 976) == 0..<1)
  }
}

@MainActor
struct CompletionRecordsTests {
  private func container() throws -> ModelContainer {
    try ModelContainer(
      for: Goal.self, Completion.self, Day.self,
      configurations: ModelConfiguration(
        isStoredInMemoryOnly: true, cloudKitDatabase: .none
      )
    )
  }

  @Test func rapidTapsReusePendingInsertAndToggleCorrectly() throws {
    let container = try container()
    let context = container.mainContext
    context.autosaveEnabled = false
    let goal = Goal(name: "Test")
    context.insert(goal)
    for _ in 0..<2 {
      try CompletionRecords.toggle(
        .completed, goal: goal, dateKey: "2026-09-25", in: context
      )
    }
    let records = try context.fetch(FetchDescriptor<Completion>())
    #expect(records.count == 1)
    #expect(records.first?.state == .unmarked)
    try CompletionRecords.toggle(
      .failed, goal: goal, dateKey: "2026-09-25", in: context
    )
    #expect(records.first?.state == .failed)
  }

  @Test func newestDuplicateControlsDisplayAndAllDuplicatesAreEdited() throws {
    let container = try container()
    let context = container.mainContext
    let goal = Goal(name: "Test")
    let otherGoal = Goal(name: "Other")
    context.insert(goal)
    context.insert(otherGoal)
    let old = Completion(dateKey: "2026-09-25", goal: goal)
    let newest = Completion(dateKey: old.dateKey, goal: goal)
    let other = Completion(dateKey: old.dateKey, goal: otherGoal)
    old.updatedAt = .distantPast
    newest.state = .skipped
    newest.note = "Keep this"
    for record in [old, newest, other] { context.insert(record) }
    #expect(CompletionRecords.latest([newest, old]) === newest)
    #expect(CompletionRecords.byGoal([old, newest, other])[goal.id]?.count == 2)
    try CompletionRecords.toggle(
      .skipped, goal: goal, dateKey: old.dateKey, in: context
    )
    #expect(old.state == .unmarked && newest.state == .unmarked)
    #expect(other.state == .completed)
    #expect(newest.note == "Keep this")
    try CompletionRecords.saveNote(
      "Updated", goal: goal, dateKey: old.dateKey, in: context
    )
    #expect(old.note == "Updated" && newest.note == "Updated")
    #expect(other.note.isEmpty)
  }

  @Test func noteOnlyInsertAndWhitespacePreserveMarkSemantics() throws {
    let container = try container()
    let context = container.mainContext
    let goal = Goal(name: "Test")
    context.insert(goal)
    try CompletionRecords.saveNote(
      " \n", goal: goal, dateKey: "2026-09-01", in: context
    )
    #expect(try context.fetchCount(FetchDescriptor<Completion>()) == 0)
    try CompletionRecords.saveNote(
      "Context", goal: goal, dateKey: "2026-09-01", in: context
    )
    let record = try #require(context.fetch(FetchDescriptor<Completion>()).first)
    #expect(record.state == .unmarked)
    record.state = .failed
    try CompletionRecords.saveNote(
      "\n", goal: goal, dateKey: record.dateKey, in: context
    )
    #expect(record.state == .failed && record.note.isEmpty)
  }

  @Test func widgetUsesTheSameLatestDuplicateAsTheCell() {
    let goal = Goal(name: "Test")
    let old = Completion(dateKey: "2026-09-25", goal: goal)
    let newest = Completion(dateKey: old.dateKey, goal: goal)
    old.updatedAt = .distantPast
    newest.state = .failed
    let updater = WidgetSummaryUpdater(
      dateKey: old.dateKey, goals: [goal], days: [],
      completions: [old, newest]
    )
    #expect(updater.summary.count == 0)
    newest.state = .completed
    #expect(updater.summary.count == 1)
  }
}
