import Foundation
import SwiftData
import Testing
@testable import habit_tracker

@MainActor
struct TodayHabitsTests {
  @Test func reorderingMovesOnlyTheDraggedHabitAcrossHiddenSlots() {
    let goals = ["A", "B", "C", "D"].enumerated().map {
      Goal(name: $0.element, sortOrder: $0.offset)
    }
    // B is hidden in Today. Moving D before A must not pin B to slot 1.
    GoalOrdering.move(goals[3].id, before: goals[0].id, in: goals)
    #expect(goals.sorted { $0.sortOrder < $1.sortOrder }.map(\.name)
      == ["D", "A", "B", "C"])
    let ordered = goals.sorted { $0.sortOrder < $1.sortOrder }
    GoalOrdering.move(goals[0].id, before: nil, in: ordered)
    #expect(goals.sorted { $0.sortOrder < $1.sortOrder }.map(\.name)
      == ["D", "B", "C", "A"])
  }

  @Test func downwardMovesLandImmediatelyBeforeTheTarget() {
    let goals = ["A", "B", "C", "D"].enumerated().map {
      Goal(name: $0.element, sortOrder: $0.offset)
    }
    GoalOrdering.move(goals[0].id, before: goals[3].id, in: goals)
    #expect(goals.sorted { $0.sortOrder < $1.sortOrder }.map(\.name)
      == ["B", "C", "A", "D"])
  }

  @Test func staleOrSelfDropLeavesOrderIntact() {
    let goals = [Goal(name: "A", sortOrder: 3), Goal(name: "B", sortOrder: 7)]
    GoalOrdering.move(UUID(), before: nil, in: goals)
    GoalOrdering.move(goals[0].id, before: UUID(), in: goals)
    GoalOrdering.move(goals[0].id, before: goals[0].id, in: goals)
    #expect(goals.map(\.sortOrder) == [3, 7])
  }

  @Test func newestIntentionControlsPromptWithoutPersistingEmptyDismissal() {
    let old = Day(dateKey: "2026-10-02", intentionText: "Read")
    old.intentionUpdatedAt = .distantPast
    let new = Day(dateKey: old.dateKey)
    new.intentionText = " \n "
    new.intentionUpdatedAt = .now
    #expect(!TodayHabits.intentionIsSatisfied([]))
    #expect(TodayHabits.intentionIsSatisfied([old]))
    #expect(!TodayHabits.intentionIsSatisfied([old, new]))
    new.intentionText = "Rest"
    #expect(TodayHabits.intentionIsSatisfied([old, new]))
  }

  @Test func celebrationsRequireFinishedHabitsAndAnAllowedFinalMark() {
    #expect(TodayHabits.shouldCelebrate(
      states: [.failed, .completed], finalMark: .completed
    ))
    #expect(TodayHabits.shouldCelebrate(states: [.skipped], finalMark: .skipped))
    #expect(!TodayHabits.shouldCelebrate(
      states: [.completed, .failed], finalMark: .failed
    ))
    #expect(!TodayHabits.shouldCelebrate(states: [], finalMark: .completed))
    #expect(!TodayHabits.shouldCelebrate(
      states: [.unmarked, .completed], finalMark: .completed
    ))
  }

  @Test func celebrationSignatureIgnoresNotesAndOrderButDetectsChangedMarks() {
    let goal = Goal(name: "A")
    let other = Goal(name: "B")
    let record = Completion(dateKey: "2026-10-02", goal: goal)
    let otherRecord = Completion(dateKey: record.dateKey, goal: other)
    let records = [goal.id: record, other.id: otherRecord]
    let original = TodayHabits.signature(
      dateKey: record.dateKey, goals: [goal, other], records: records
    )
    record.note = "Updated note"
    record.updatedAt = .now
    #expect(TodayHabits.signature(
      dateKey: record.dateKey, goals: [other, goal], records: records
    ) == original)
    record.state = .failed
    #expect(TodayHabits.signature(
      dateKey: record.dateKey, goals: [goal, other], records: records
    ) != original)
  }

  @Test func finishedMembershipUsesNewestDuplicateNotAnyHistoricalMark() {
    let goal = Goal(name: "A")
    let old = Completion(dateKey: "2026-10-02", goal: goal)
    old.updatedAt = .distantPast
    let latest = Completion(dateKey: old.dateKey, goal: goal)
    latest.state = .unmarked
    #expect(TodayHabits.latestByGoal([old, latest])[goal.id]?.state == .unmarked)
  }
}
