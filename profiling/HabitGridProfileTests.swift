// Copy into habit-trackerTests to run explicitly on an iOS Simulator.
// Kept outside the test target so profiling does not slow ordinary tests.
#if targetEnvironment(simulator)
import Darwin
import SwiftData
import SwiftUI
import UIKit
import XCTest
@testable import habit_tracker

@MainActor
final class HabitGridProfileTests: XCTestCase {
  func testHistoryScaling() async throws {
    // Same stored history, varying the number of materialized columns.
    for (days, columns) in [(7, 7), (30, 30), (60, 60),
      (60, 30), (60, 7), (180, 180), (180, 30)] {
      try await profile(days: days, columns: columns)
    }
  }

  func testAutosaveScaling() async throws {
    for columns in [60, 30, 7, 0] {
      try await profile(days: 60, columns: columns, explicitSave: false)
    }
  }

  func testFirstCompletionScaling() async throws {
    for columns in [60, 30, 7, 0] {
      try await profile(
        days: 60, columns: columns,
        explicitSave: false, inserting: true
      )
    }
  }

  private func profile(
    days: Int, columns: Int, explicitSave: Bool = true,
    inserting: Bool = false
  ) async throws {
    let container = try ModelContainer(
      for: Goal.self, Completion.self, Day.self,
      configurations: ModelConfiguration(
        isStoredInMemoryOnly: true, cloudKitDatabase: .none
      )
    )
    let context = container.mainContext
    context.autosaveEnabled = false
    let today = DayBoundary.dateKey()
    var keys = [today]
    for _ in 1..<days {
      keys.append(DayBoundary.yesterdayKey(from: keys.last!))
    }
    for key in keys { context.insert(Day(dateKey: key)) }
    var records: [Completion] = []
    var goals: [Goal] = []
    for index in 0..<20 {
      let goal = Goal(name: "Habit \(index)", sortOrder: index)
      context.insert(goal)
      goals.append(goal)
      for key in keys where !inserting || key != today {
        let completion = Completion(dateKey: key, goal: goal)
        context.insert(completion)
        records.append(completion)
      }
    }
    try context.save()
    context.autosaveEnabled = !explicitSave
    var target = records[0]
    let scene = try XCTUnwrap(
      UIApplication.shared.connectedScenes.first as? UIWindowScene
    )
    let window = UIWindow(windowScene: scene)
    window.frame = CGRect(x: 0, y: 0, width: 393, height: 852)
    let host = UIHostingController(rootView:
      Group {
        if columns > 0 {
          ProfileGrid(today: today, cutoff: keys[columns - 1])
        } else {
          Color.clear
        }
      }
        .modelContainer(container)
    )
    window.rootViewController = host
    window.makeKeyAndVisible()
    defer {
      window.isHidden = true
      window.rootViewController = nil
    }
    host.view.layoutIfNeeded()
    try await Task.sleep(for: .seconds(2))

    // Report process CPU separately from elapsed observation windows.
    // This includes query updates/layout, but is not tap-to-photon latency.
    var cpuSamples: [Double] = []
    var wallSamples: [Double] = []
    var mutationSamples: [Double] = []
    var saveSamples: [Double] = []
    for iteration in 0..<12 {
      let cpuStart = cpuTime()
      let start = CACurrentMediaTime()
      if inserting {
        target = Completion(dateKey: today, goal: goals[iteration])
        context.insert(target)
      } else {
        target.state = iteration.isMultiple(of: 2)
          ? .unmarked : .completed
      }
      target.updatedAt = .now
      let mutationEnd = CACurrentMediaTime()
      if explicitSave { try context.save() }
      let saveEnd = CACurrentMediaTime()
      try await Task.sleep(for: .milliseconds(150))
      host.view.layoutIfNeeded()
      cpuSamples.append((cpuTime() - cpuStart) * 1_000)
      wallSamples.append((CACurrentMediaTime() - start) * 1_000)
      mutationSamples.append((mutationEnd - start) * 1_000)
      saveSamples.append((saveEnd - mutationEnd) * 1_000)
    }
    func median(_ values: [Double]) -> String {
      let sorted = values.sorted()
      return String(format: "%.2f", sorted[sorted.count / 2])
    }
    print("HABIT_PROFILE days=\(days) columns=\(columns) goals=20"
      + " explicit_save=\(explicitSave)"
      + " inserting=\(inserting)"
      + " cpu_ms=\(median(cpuSamples))"
      + " window_ms=\(median(wallSamples))"
      + " mutation_ms=\(median(mutationSamples))"
      + " save_ms=\(median(saveSamples))")
    XCTAssertEqual(target.state, .completed)
  }

  private func cpuTime() -> Double {
    var usage = rusage()
    getrusage(RUSAGE_SELF, &usage)
    return Double(usage.ru_utime.tv_sec + usage.ru_stime.tv_sec)
      + Double(usage.ru_utime.tv_usec + usage.ru_stime.tv_usec)
        / 1_000_000
  }
}

private struct ProfileGrid: View {
  @Query(sort: \Goal.sortOrder) private var goals: [Goal]
  @Query(sort: \Day.dateKey) private var days: [Day]
  @Query(sort: \Completion.dateKey) private var completions: [Completion]
  let today: String
  let cutoff: String

  var body: some View {
    HabitGridView(
      goals: goals,
      visibleDays: days.filter { $0.dateKey >= cutoff },
      completions: completions,
      hiddenDateKeys: [],
      effectiveTodayKey: today,
      selectedDateKey: today,
      onSelectDate: { _ in },
      onDeleteDate: { _ in },
      onSpawnTomorrow: {},
      onInsertDate: { _ in }
    )
  }
}
#endif
