import Testing
import Foundation
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
