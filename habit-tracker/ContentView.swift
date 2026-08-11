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

  @Query(sort: \Goal.sortOrder)
  private var allGoals: [Goal]

  @Query(
    filter: #Predicate<Day> { !$0.isHidden },
    sort: \Day.dateKey
  )
  private var visibleDays: [Day]

  @Query(sort: \Day.dateKey)
  private var allDays: [Day]

  @Query(sort: \Completion.dateKey)
  private var allCompletions: [Completion]

  @State private var effectiveTodayKey: String =
    DayBoundary.dateKey()
  @State private var selectedDateKey: String =
    DayBoundary.dateKey()
  @State private var isShowingExport = false
  @State private var isShowingArchive = false
  @FocusState private var isIntentionFocused: Bool

  var body: some View {
    ZStack(alignment: .topTrailing) {
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
          completions: allCompletions,
          hiddenDateKeys: hiddenDateKeys,
          effectiveTodayKey: effectiveTodayKey,
          selectedDateKey: selectedDateKey,
          onSelectDate: { key in
            isIntentionFocused = false
            selectedDateKey = key
          },
          onDeleteDate: { day in
            deleteDate(day.dateKey)
          },
          onSpawnTomorrow: {
            spawnTomorrow()
          },
          onInsertDate: { key in
            insertDate(key)
          },
          onGridTapped: {
            isIntentionFocused = false
          },
          onShowArchive: {
            isIntentionFocused = false
            isShowingArchive = true
          }
        )
      }

      Button {
        isIntentionFocused = false
        isShowingExport = true
      } label: {
        Image(systemName: "square.and.arrow.up")
          .font(.body)
          .padding(12)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityLabel("Export Habit Data")
      .accessibilityIdentifier("exportHabitDataButton")
    }
    .onAppear {
      ensureTodayExists()
      syncWidgetSummary()
      saveWeeklyBackupIfNeeded()
    }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        ensureTodayExists()
        syncWidgetSummary()
        saveWeeklyBackupIfNeeded()
      }
    }
    .onChange(of: widgetSummaryFingerprint) {
      syncWidgetSummary()
    }
    .sheet(isPresented: $isShowingExport) {
      ExportDataView()
    }
    .sheet(isPresented: $isShowingArchive) {
      ArchivedGoalsView()
    }
  }

  private var todayIntentionText: String? {
    let matchingDays = allDays.filter {
      $0.dateKey == effectiveTodayKey
    }
    let day = matchingDays.max {
      ($0.intentionUpdatedAt ?? .distantPast)
        < ($1.intentionUpdatedAt ?? .distantPast)
    }
    let trimmed = day?.intentionText.trimmingCharacters(
      in: .whitespacesAndNewlines
    ) ?? ""
    return trimmed.isEmpty ? nil : trimmed
  }

  private var hiddenDateKeys: Set<String> {
    let hiddenKeys = Set(
      allDays.filter(\.isHidden).map(\.dateKey)
    )
    return hiddenKeys.subtracting(visibleDays.map(\.dateKey))
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
    let restoredTodayKey = DayBoundary.effectiveTodayKey(
      calendarTodayKey: todayKey,
      visibleDateKeys: allDays
        .filter { !$0.isHidden }
        .map(\.dateKey)
    )
    effectiveTodayKey = restoredTodayKey
    selectedDateKey = restoredTodayKey

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

  private func deleteDate(_ dateKey: String) {
    let outcome = withAnimation {
      DayDeletion.hide(
        dateKey: dateKey,
        in: allDays,
        selectedDateKey: selectedDateKey,
        effectiveTodayKey: effectiveTodayKey
      )
    }

    if outcome.shouldEnsureTodayExists {
      ensureTodayExists()
    } else {
      selectedDateKey = outcome.selectedDateKey
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
      dateKey: effectiveTodayKey,
      todayIntention: todayIntentionText,
      completedCount: completedGoalsTodayCount
    )
  }

  private func saveWeeklyBackupIfNeeded() {
    let keys = allDays.map(\.dateKey)
      + allCompletions.map(\.dateKey)
    let fallbackKey = DayBoundary.dateKey()
    let startKey = keys.min() ?? fallbackKey
    let endKey = keys.max() ?? fallbackKey
    let export = HabitDataExport.make(
      goals: allGoals,
      days: allDays,
      completions: allCompletions,
      startDateKey: startKey,
      endDateKey: endKey
    )

    try? HabitBackupStore.saveWeeklyIfNeeded(export)
  }
}

#Preview {
  let container = try! ModelContainer(
    for: Goal.self, Completion.self, Day.self,
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
        Goal.self, Completion.self, Day.self
      ],
      inMemory: true
    )
}
