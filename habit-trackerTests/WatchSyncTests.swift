import Foundation
import SwiftData
import Testing
@testable import habit_tracker

@MainActor
struct WatchSyncTests {
  private let key = "2026-10-11"

  private func container() throws -> ModelContainer {
    let schema = Schema(versionedSchema: HabitSchemaV6.self)
    return try ModelContainer(
      for: schema,
      configurations: ModelConfiguration(
        schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none
      )
    )
  }

  @Test func redeliveredMarksAreIdempotentAndPreserveNotes() throws {
    let container = try container()
    let context = container.mainContext
    let goal = Goal(name: "Read")
    context.insert(goal)
    let record = Completion(dateKey: key, goal: goal)
    record.state = .unmarked
    record.note = "Keep this phone note"
    record.updatedAt = .distantPast
    context.insert(record)
    try context.save()
    let edit = WatchEdit(dateKey: key, value: .mark(goalID: goal.id, state: .skipped))
    try WatchEdits.apply(edit, in: context)
    try WatchEdits.apply(edit, in: context)
    #expect(record.state == .skipped)
    #expect(record.note == "Keep this phone note")
    #expect(try context.fetchCount(FetchDescriptor<Completion>()) == 1)
  }

  @Test func delayedEditsCannotReverseNewerMarksOrClearTombstones() throws {
    let container = try container()
    let context = container.mainContext
    let goal = Goal(name: "Read")
    context.insert(goal)
    try context.save()
    let old = WatchEdit(
      dateKey: key, updatedAt: Date(timeIntervalSince1970: 10),
      value: .mark(goalID: goal.id, state: .completed)
    )
    let clear = WatchEdit(
      dateKey: key, updatedAt: Date(timeIntervalSince1970: 20),
      value: .mark(goalID: goal.id, state: .unmarked)
    )
    try WatchEdits.apply(clear, in: context)
    try WatchEdits.apply(old, in: context)
    let records = try CompletionRecords.fetch(goal: goal, dateKey: key, in: context)
    #expect(records.count == 1)
    #expect(records.first?.state == .unmarked)
  }

  @Test func marksUpdateDuplicatesAndIgnoreArchivedHabits() throws {
    let container = try container()
    let context = container.mainContext
    let goal = Goal(name: "Read")
    context.insert(goal)
    let records = (0..<2).map { _ in Completion(dateKey: key, goal: goal) }
    for record in records {
      record.updatedAt = .distantPast
      context.insert(record)
    }
    try context.save()
    try WatchEdits.apply(WatchEdit(
      dateKey: key, value: .mark(goalID: goal.id, state: .failed)
    ), in: context)
    #expect(records.allSatisfy { $0.state == .failed })
    goal.archivedAt = .now
    try context.save()
    try WatchEdits.apply(WatchEdit(
      dateKey: key, value: .mark(goalID: goal.id, state: .completed)
    ), in: context)
    #expect(records.allSatisfy { $0.state == .failed })
  }

  @Test func intentionEditsResolveDuplicatesAndPreserveOtherDays() throws {
    let container = try container()
    let context = container.mainContext
    let yesterday = Day(dateKey: "2026-10-10", intentionText: "Yesterday")
    let first = Day(dateKey: key)
    let second = Day(dateKey: key)
    for day in [first, second, yesterday] { context.insert(day) }
    try context.save()
    let edit = WatchEdit(dateKey: key, value: .intention("Be present"))
    try WatchEdits.apply(edit, in: context)
    try WatchEdits.apply(WatchEdit(
      dateKey: key, updatedAt: .distantPast, value: .intention("Older")
    ), in: context)
    #expect(first.intentionText == "Be present")
    #expect(second.intentionText == "Be present")
    #expect(yesterday.intentionText == "Yesterday")
    try WatchEdits.apply(WatchEdit(dateKey: key, value: .intention("")), in: context)
    #expect(first.intentionText.isEmpty && second.intentionText.isEmpty)
  }

  @Test func backgroundReceiptIsVisibleToThePhoneContext() throws {
    let container = try container()
    let phone = container.mainContext
    let goal = Goal(name: "Read")
    phone.insert(goal)
    let record = Completion(dateKey: key, goal: goal)
    record.state = .unmarked
    record.updatedAt = .distantPast
    phone.insert(record)
    try phone.save()
    let receiver = ModelContext(container)
    try WatchEdits.apply(WatchEdit(
      dateKey: key, value: .mark(goalID: goal.id, state: .completed)
    ), in: receiver)
    // Check the already-registered object used by the visible phone row.
    let records = try CompletionRecords.fetch(goal: goal, dateKey: key, in: phone)
    #expect(CompletionRecords.latest(records)?.state == .completed)
  }

  @Test func snapshotIncludesOnlyTodaysActiveHabitsInOrder() {
    let first = Goal(name: "A", sortOrder: 1)
    let second = Goal(name: "B", sortOrder: 2)
    let archived = Goal(name: "Hidden")
    archived.archivedAt = .now
    let oldRecord = Completion(dateKey: "2026-10-10", goal: first)
    let current = Completion(dateKey: key, goal: second)
    current.state = .failed
    let today = WatchEdits.today(
      dateKey: key, goals: [second, archived, first],
      days: [Day(dateKey: key, intentionText: "Read")],
      completions: [oldRecord, current]
    )
    #expect(today.habits.map(\.name) == ["A", "B"])
    #expect(today.habits.map(\.state) == [.unmarked, .failed])
    #expect(today.intention == "Read")
  }

  @Test func outOfOrderReceiptsRetainNewerSnapshotAndUnacknowledgedEdits() {
    let goalID = UUID()
    let today = WatchToday(dateKey: key, intention: "", habits: [
      .init(id: goalID, name: "Read", state: .unmarked)
    ])
    let first = WatchEdit(
      dateKey: key, updatedAt: Date(timeIntervalSince1970: 10),
      value: .mark(goalID: goalID, state: .completed)
    )
    let second = WatchEdit(
      dateKey: key, updatedAt: Date(timeIntervalSince1970: 20),
      value: .mark(goalID: goalID, state: .failed)
    )
    let newer = WatchSnapshot(generatedAt: Date(timeIntervalSince1970: 30), today: today)
    var cache = WatchCache(snapshot: newer, pending: [first, second])
    cache.receive(WatchReply(
      snapshot: WatchSnapshot(generatedAt: .distantPast, today: today),
      acknowledged: [first.id]
    ))
    #expect(cache.snapshot == newer)
    #expect(cache.pending == [second])
    #expect(cache.snapshot?.today.applying(cache.pending, on: key)
      .habits.first?.state == .failed)
  }

  @Test func offlineRolloverClearsYesterdayWithoutLosingQueuedEdits() throws {
    let id = UUID()
    let yesterday = WatchToday(dateKey: "2026-10-10", intention: "Rest", habits: [
      .init(id: id, name: "Read", state: .completed)
    ])
    let edits = [
      WatchEdit(dateKey: "2026-10-10", value: .mark(goalID: id, state: .failed)),
      WatchEdit(dateKey: key, value: .intention("Learn"))
    ]
    let cache = WatchCache(snapshot: WatchSnapshot(today: yesterday), pending: edits)
    let restored = try JSONDecoder().decode(
      WatchCache.self, from: JSONEncoder().encode(cache)
    )
    #expect(restored == cache)
    let today = restored.snapshot!.today.applying(restored.pending, on: key)
    #expect(today.habits.first?.state == .unmarked)
    #expect(today.intention == "Learn")
    #expect(restored.pending.count == 2)
  }

  @Test func wireRoundTripIncludesClearAndEmptyIntention() throws {
    let edits = [
      WatchEdit(dateKey: key, value: .mark(goalID: UUID(), state: .unmarked)),
      WatchEdit(dateKey: key, value: .intention(""))
    ]
    for edit in edits {
      #expect(try WatchWire.decode(WatchEdit.self, from: WatchWire.encode(edit)) == edit)
    }
  }
}
