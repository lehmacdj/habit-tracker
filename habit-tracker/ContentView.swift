import SwiftUI
import SwiftData

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase

  @Query(
    filter: #Predicate<Goal> { !$0.isDeleted },
    sort: \Goal.sortOrder
  )
  private var goals: [Goal]

  @Query(
    filter: #Predicate<Day> { !$0.isHidden },
    sort: \Day.dateKey
  )
  private var visibleDays: [Day]

  @Query(sort: \Day.dateKey)
  private var allDays: [Day]

  @Query(sort: \Intention.updatedAt, order: .reverse)
  private var intentions: [Intention]

  @State private var effectiveTodayKey: String =
    DayBoundary.dateKey()
  @State private var selectedDateKey: String =
    DayBoundary.dateKey()
  @FocusState private var isIntentionFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      IntentionView(
        dateKey: selectedDateKey,
        isToday: selectedDateKey == effectiveTodayKey,
        isFocused: $isIntentionFocused
      )
      .id(selectedDateKey)

      HabitGridView(
        goals: goals,
        visibleDays: visibleDays,
        effectiveTodayKey: effectiveTodayKey,
        selectedDateKey: selectedDateKey,
        onSelectDate: { key in
          isIntentionFocused = false
          selectedDateKey = key
        },
        onDeleteDate: { day in
          let wasEffectiveToday =
            day.dateKey == effectiveTodayKey
          withAnimation {
            day.isHidden = true
          }
          if wasEffectiveToday {
            ensureTodayExists()
          }
        },
        onSpawnTomorrow: {
          spawnTomorrow()
        },
        onInsertDate: { key in
          insertDate(key)
        },
        onGridTapped: {
          isIntentionFocused = false
        }
      )
    }
    .onAppear {
      ensureTodayExists()
      syncWidgetSummary()
    }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        ensureTodayExists()
        syncWidgetSummary()
      }
    }
    .onChange(of: widgetSummaryFingerprint) {
      syncWidgetSummary()
    }
  }

  private var todayIntentionText: String? {
    let trimmed = intentions.first {
      $0.dateKey == effectiveTodayKey
    }?.text.trimmingCharacters(
      in: .whitespacesAndNewlines
    ) ?? ""
    return trimmed.isEmpty ? nil : trimmed
  }

  private var completedGoalsTodayCount: Int {
    goals.filter { goal in
      goal.completions?.contains {
        $0.dateKey == effectiveTodayKey && $0.isCompleted
      } ?? false
    }.count
  }

  private var widgetSummaryFingerprint: String {
    [
      effectiveTodayKey,
      todayIntentionText ?? "",
      String(completedGoalsTodayCount)
    ].joined(separator: "|")
  }

  /// Ensures Day records exist for today and the previous day.
  private func ensureTodayExists() {
    let todayKey = DayBoundary.dateKey()
    effectiveTodayKey = todayKey
    selectedDateKey = todayKey

    ensureDayVisible(todayKey)
    ensureDayVisible(
      DayBoundary.yesterdayKey(from: todayKey)
    )
  }

  /// Spawns tomorrow's date. Tomorrow becomes the new
  /// effective "today", and the actual today shifts into
  /// past dates.
  private func spawnTomorrow() {
    let calendarToday = DayBoundary.dateKey()
    let tomorrowKey = DayBoundary.tomorrowKey(
      from: calendarToday
    )

    ensureDayVisible(tomorrowKey)

    withAnimation {
      effectiveTodayKey = tomorrowKey
      selectedDateKey = tomorrowKey
    }
  }

  private func insertDate(_ dateKey: String) {
    withAnimation {
      ensureDayVisible(dateKey)
      if dateKey > effectiveTodayKey {
        effectiveTodayKey = dateKey
      }
      selectedDateKey = dateKey
    }
  }

  private func ensureDayVisible(_ dateKey: String) {
    if allDays.contains(
      where: { $0.dateKey == dateKey && !$0.isHidden }
    ) {
      return
    }

    if let hiddenDay = allDays.first(
      where: { $0.dateKey == dateKey }
    ) {
      hiddenDay.isHidden = false
    } else {
      modelContext.insert(Day(dateKey: dateKey))
    }
  }

  private func syncWidgetSummary() {
    HabitWidgetSummaryStore.save(
      todayIntention: todayIntentionText,
      completedCount: completedGoalsTodayCount
    )
  }
}

#Preview {
  let container = try! ModelContainer(
    for: Goal.self, Completion.self, Intention.self, Day.self,
    configurations: ModelConfiguration(isStoredInMemoryOnly: true)
  )
  let ctx = container.mainContext
  let todayKey = DayBoundary.dateKey()
  let yesterdayKey = DayBoundary.yesterdayKey(from: todayKey)
  let twoDaysAgo = DayBoundary.yesterdayKey(from: yesterdayKey)
  ctx.insert(Day(dateKey: twoDaysAgo))
  ctx.insert(Day(dateKey: yesterdayKey))
  ctx.insert(Day(dateKey: todayKey))
  let g1 = Goal(name: "Exercise", sortOrder: 0)
  let g2 = Goal(name: "Read", sortOrder: 1)
  let g3 = Goal(name: "Meditate", sortOrder: 2)
  ctx.insert(g1); ctx.insert(g2); ctx.insert(g3)
  ctx.insert(Completion(dateKey: yesterdayKey, goal: g1))
  ctx.insert(Completion(dateKey: todayKey, goal: g2))
  return ContentView()
    .modelContainer(container)
}

#Preview("Empty State") {
  ContentView()
    .modelContainer(
      for: [
        Goal.self, Completion.self,
        Intention.self, Day.self
      ],
      inMemory: true
    )
}
