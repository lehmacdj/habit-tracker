import SwiftUI
import SwiftData

struct ContentView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase

  @Query(
    filter: #Predicate<Goal> {
      $0.archivedAt == nil && !$0.isDeleted
    },
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
  @State private var isShowingToday = true
  @State private var todayIsReady = false
  @State private var todayVisit = UUID()
  @State private var isShowingExport = false
  @State private var isShowingArchive = false
  @State private var isShowingSyncStatus = false
  @ObservedObject private var cloudSyncMonitor =
    CloudSyncMonitor.shared
  @FocusState private var isIntentionFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 0) {
        if !isShowingToday || todayIsReady {
          Button {
            isIntentionFocused = false
            if isShowingToday {
              isShowingToday = false
              selectedDateKey = effectiveTodayKey
            } else {
              showToday()
            }
          } label: {
            Label(
              isShowingToday ? "Grid" : "Today",
              systemImage: isShowingToday ? "square.grid.3x3" : "checklist"
            )
            .padding(12)
          }
          .buttonStyle(.plain)
          .accessibilityIdentifier(
            isShowingToday ? "showGridButton" : "showTodayButton"
          )
        }
        Spacer()
        Button {
          isIntentionFocused = false
          isShowingSyncStatus = true
        } label: {
          Image(
            systemName: cloudSyncMonitor.needsAttention
              ? "exclamationmark.icloud.fill"
              : "icloud"
          )
          .font(.body)
          .foregroundStyle(
            cloudSyncMonitor.needsAttention
              ? Color.red
              : Color.primary
          )
          .padding(12)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
          cloudSyncMonitor.needsAttention
            ? "Cloud Sync Needs Attention"
            : "Cloud Sync Status"
        )
        .accessibilityIdentifier("cloudSyncStatusButton")

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
      if isShowingToday {
        TodayView(
          goals: goals,
          days: allDays.filter { $0.dateKey == effectiveTodayKey },
          completions: allCompletions.filter { $0.dateKey == effectiveTodayKey },
          dateKey: effectiveTodayKey,
          onShowGrid: {
            selectedDateKey = effectiveTodayKey
            isShowingToday = false
          },
          onShowArchive: { isShowingArchive = true },
          onReadyChanged: { todayIsReady = $0 }
        )
        .id(effectiveTodayKey + todayVisit.uuidString)
      } else {
        VStack(spacing: 0) {
          IntentionView(
            dateKey: selectedDateKey,
            todayKey: effectiveTodayKey,
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
      }
    }
    .onOpenURL { url in
      guard url.scheme == "habit-tracker", url.host == "today" else { return }
      ensureTodayExists()
      showToday()
    }
    .task {
      // Refresh even if the app remains visible across the 4 a.m. boundary.
      while !Task.isCancelled {
        do { try await Task.sleep(for: .seconds(30)) }
        catch { return }
        if effectiveTodayKey != DayBoundary.dateKey() { ensureTodayExists() }
      }
    }
    .onAppear {
      cloudSyncMonitor.refreshAccountStatus()
      ensureTodayExists()
      saveWeeklyBackupIfNeeded()
    }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase == .active {
        cloudSyncMonitor.refreshAccountStatus()
        ensureTodayExists()
        saveWeeklyBackupIfNeeded()
      }
    }
    .background {
      WidgetSummaryUpdater(
        dateKey: effectiveTodayKey, goals: goals,
        days: allDays.filter { $0.dateKey == effectiveTodayKey },
        completions: allCompletions.filter {
          $0.dateKey == effectiveTodayKey
        }
      )
    }
    .sheet(isPresented: $isShowingExport) {
      ExportDataView()
    }
    .sheet(isPresented: $isShowingArchive) {
      ArchivedGoalsView()
    }
    .sheet(isPresented: $isShowingSyncStatus) {
      CloudSyncStatusView(monitor: cloudSyncMonitor)
    }
  }

  private func showToday() {
    isIntentionFocused = false
    isShowingExport = false
    isShowingArchive = false
    isShowingSyncStatus = false
    todayIsReady = false
    todayVisit = UUID()
    isShowingToday = true
  }

  private var hiddenDateKeys: Set<String> {
    let hiddenKeys = Set(
      allDays.filter(\.isHidden).map(\.dateKey)
    )
    return hiddenKeys.subtracting(visibleDays.map(\.dateKey))
  }

  /// Ensures Day records exist for today and the previous day.
  private func ensureTodayExists() {
    let now = Date.now
    let todayKey = DayBoundary.dateKey(for: now)
    if effectiveTodayKey != todayKey {
      effectiveTodayKey = todayKey
      selectedDateKey = todayKey
      todayIsReady = false
    }

    ensureDayVisible(todayKey)
    ensureDayVisible(
      DayBoundary.yesterdayKey(from: todayKey)
    )
  }

  /// Spawns tomorrow's date to the right of today.
  private func spawnTomorrow() {
    let calendarToday = DayBoundary.dateKey()
    let tomorrowKey = DayBoundary.tomorrowKey(
      from: calendarToday
    )

    ensureDayVisible(tomorrowKey)

    withAnimation {
      selectedDateKey = tomorrowKey
    }
  }

  private func insertDate(_ dateKey: String) {
    withAnimation {
      ensureDayVisible(dateKey)
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
