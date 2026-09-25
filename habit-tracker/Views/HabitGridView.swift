import SwiftUI
import SwiftData

/// The query boundary indexes membership once. Scrolling state lives in
/// the child, so scrolling does not repeatedly read the whole history.
struct HabitGridView: View {
  let goals: [Goal]
  let visibleDays: [Day]
  let completions: [Completion]
  let hiddenDateKeys: Set<String>
  let effectiveTodayKey: String
  let selectedDateKey: String
  let onSelectDate: (String) -> Void
  let onDeleteDate: (Day) -> Void
  let onSpawnTomorrow: () -> Void
  let onInsertDate: (String) -> Void
  var onGridTapped: (() -> Void)? = nil
  var onShowArchive: (() -> Void)? = nil

  var body: some View {
    HabitGridContent(
      goals: goals,
      visibleDays: visibleDays,
      completionsByGoal: CompletionRecords.byGoal(completions),
      dayColumnLayout: DayColumnLayout(
        visibleDateKeys: visibleDays.map(\.dateKey),
        todayKey: effectiveTodayKey
      ),
      visibleDateKeySet: Set(visibleDays.map(\.dateKey)),
      hiddenDateKeys: hiddenDateKeys,
      effectiveTodayKey: effectiveTodayKey,
      selectedDateKey: selectedDateKey,
      onSelectDate: onSelectDate,
      onDeleteDate: onDeleteDate,
      onSpawnTomorrow: onSpawnTomorrow,
      onInsertDate: onInsertDate,
      onGridTapped: onGridTapped,
      onShowArchive: onShowArchive
    )
  }
}

private struct HabitGridContent: View {
  @Environment(\.modelContext) private var modelContext
  let goals: [Goal]
  let visibleDays: [Day]
  let completionsByGoal: [UUID: [Completion]]
  let dayColumnLayout: DayColumnLayout
  let visibleDateKeySet: Set<String>
  let hiddenDateKeys: Set<String>
  let effectiveTodayKey: String
  let selectedDateKey: String
  let onSelectDate: (String) -> Void
  let onDeleteDate: (Day) -> Void
  let onSpawnTomorrow: () -> Void
  let onInsertDate: (String) -> Void
  var onGridTapped: (() -> Void)? = nil
  var onShowArchive: (() -> Void)? = nil

  @State private var newGoalId: UUID? = nil
  @State private var isOverscrollingRight = false
  @State private var spawnTomorrowProgress = 0.0
  @State private var isSpawnTomorrowReady = false
  @State private var isInteractingWithGrid = false
  @State private var spawnTomorrowTask: Task<Void, Never>? = nil

  private var hasTomorrow: Bool {
    let tomorrow = DayBoundary.tomorrowKey(
      from: DayBoundary.dateKey()
    )
    return visibleDays.contains { $0.dateKey == tomorrow }
  }

  @State private var viewport: GridViewport?
  @State private var noteSelection: NoteSelection?
  @State private var pendingNote: (NoteSelection, String)?
  @State private var noteError: String?

  private var pastDateKeys: [String] {
    dayColumnLayout.pastDateKeys
  }

  private var currentAndFutureDateKeys: [String] {
    dayColumnLayout.currentAndFutureDateKeys
  }

  private let cellSize = GridViewport.cellWidth
  private let goalColumnWidth = GridViewport.goalWidth
  private let spawnTomorrowThreshold: CGFloat = 30
  private let spawnTomorrowCancelThreshold: CGFloat = 12
  private let spawnTomorrowHoldDuration: TimeInterval = 1

  /// Width of the date columns and the Goals column.
  private var contentWidth: CGFloat {
    CGFloat(
      pastDateKeys.count + currentAndFutureDateKeys.count
    ) * cellSize + goalColumnWidth
  }

  var body: some View {
    GeometryReader { geo in
      let fillWidth = max(geo.size.width - contentWidth, 0)
      let window = viewport ?? GridViewport(
        offset: max(contentWidth - geo.size.width, 0),
        width: geo.size.width
      )
      let pastRange = window.range(
        count: pastDateKeys.count, origin: fillWidth
      )
      let futureRange = window.range(
        count: currentAndFutureDateKeys.count,
        origin: fillWidth + CGFloat(pastDateKeys.count) * cellSize
          + goalColumnWidth
      )
      ScrollView([.horizontal, .vertical]) {
        VStack(spacing: 0) {
          LazyVStack(
            spacing: 0,
            pinnedViews: [.sectionHeaders]
          ) {
            Section {
              ForEach(goals) { goal in
                HabitGoalRow(
                  goal: goal,
                  completions: completionsByGoal[goal.id] ?? [],
                  layout: dayColumnLayout,
                  pastRange: pastRange,
                  futureRange: futureRange,
                  fillWidth: fillWidth,
                  hiddenDateKeys: hiddenDateKeys,
                  todayKey: effectiveTodayKey,
                  startEditing: goal.id == newGoalId,
                  onArchive: { archive(goal) },
                  onEditNote: { key in
                    onGridTapped?()
                    noteSelection = NoteSelection(goal: goal, dateKey: key)
                  }
                )
                .contentShape(Rectangle())
                .dropDestination(for: String.self) { items, _ in
                  guard let sourceId = items.compactMap(UUID.init)
                    .first else { return false }
                  withAnimation { moveGoal(from: sourceId, to: goal.id) }
                  return true
                }
                Divider()
              }
              addGoalButton(fillWidth: fillWidth)
            } header: {
              headerRow(
                fillWidth: fillWidth,
                pastRange: pastRange, futureRange: futureRange
              )
            }
          }
          Spacer(minLength: 0)
        }
        .frame(minHeight: geo.size.height)
      }
      .accessibilityIdentifier("habitGrid")
      .onScrollGeometryChange(for: GridViewport.self) { proxy in
        GridViewport(
          offset: proxy.visibleRect.minX,
          width: proxy.containerSize.width
        )
      } action: { _, newViewport in
        viewport = newViewport
      }
      .scrollIndicators(.hidden)
      .scrollDismissesKeyboard(.interactively)
      .scrollBounceBehavior(.always)
      .defaultScrollAnchor(UnitPoint(x: 1, y: 0))
      .onScrollGeometryChange(
        for: CGFloat.self
      ) { proxy in
        let maxX = max(
          proxy.contentSize.width
            - proxy.containerSize.width,
          0
        )
        return proxy.contentOffset.x - maxX
      } action: { _, overscroll in
        updateSpawnTomorrowOverscroll(overscroll)
      }
      .onScrollPhaseChange { oldPhase, newPhase in
        // Dismiss keyboard when scrolling begins
        if newPhase == .interacting {
          isInteractingWithGrid = true
          onGridTapped?()
        } else {
          isInteractingWithGrid = false
        }
        if oldPhase == .interacting
          && isSpawnTomorrowReady {
          resetSpawnTomorrowProgress()
          onSpawnTomorrow()
        } else if oldPhase == .interacting {
          resetSpawnTomorrowProgress()
        }
      }
      .overlay(alignment: .trailing) {
        if isOverscrollingRight && !hasTomorrow {
          VStack(spacing: 6) {
            Image(systemName: "arrow.left")
            Text(
              isSpawnTomorrowReady
                ? "Release"
                : "Hold for tomorrow"
            )
              .font(.caption2)
            ProgressView(value: spawnTomorrowProgress)
              .progressViewStyle(.linear)
              .frame(width: 72)
          }
          .foregroundStyle(.secondary)
          .padding(.trailing, 8)
        }
      }
      #if os(iOS)
      .sensoryFeedback(
        .success,
        trigger: isSpawnTomorrowReady
      )
      #endif
      .onDisappear {
        spawnTomorrowTask?.cancel()
      }
    }
    .sheet(item: $noteSelection, onDismiss: savePendingNote) { selection in
      CompletionNoteEditor(
        goalName: selection.goal.name,
        dateKey: selection.dateKey,
        initialText: CompletionRecords.latest(
          (completionsByGoal[selection.goal.id] ?? []).filter {
            $0.dateKey == selection.dateKey
          }
        )?.note ?? "",
        onSave: { pendingNote = (selection, $0) }
      )
    }
    .alert("Could Not Save Note", isPresented: Binding(
      get: { noteError != nil },
      set: { if !$0 { noteError = nil } }
    )) {
      Button("OK") { noteError = nil }
    } message: {
      Text(noteError ?? "Please try again.")
    }
  }

  private struct NoteSelection: Identifiable {
    let id = UUID()
    let goal: Goal
    let dateKey: String
  }

  private func savePendingNote() {
    guard let (selection, text) = pendingNote else { return }
    pendingNote = nil
    do {
      try CompletionRecords.saveNote(
        text, goal: selection.goal, dateKey: selection.dateKey,
        in: modelContext
      )
    } catch {
      noteError = "The note could not be saved. " + error.localizedDescription
    }
  }

  // MARK: - Header Row

  @ViewBuilder
  private func headerRow(
    fillWidth: CGFloat, pastRange: Range<Int>, futureRange: Range<Int>
  ) -> some View {
    HStack(spacing: 0) {
      // Left fill to push content right
      if fillWidth > 0 {
        Color.clear.frame(
          width: fillWidth, height: cellSize
        )
      }

      // Past date headers
      WindowedDayColumns(keys: pastDateKeys, range: pastRange) { key in
        let previousKey = DayBoundary.yesterdayKey(from: key)
        let nextKey = DayBoundary.tomorrowKey(from: key)
        DateHeaderView(
          dateKey: key,
          isSelected: key == selectedDateKey,
          canDelete: true,
          canInsertPrevious: !visibleDateKeySet
            .contains(previousKey),
          canInsertNext: !visibleDateKeySet.contains(nextKey),
          onTap: { onSelectDate(key) },
          onDelete: {
            if let day = visibleDays.first(
              where: { $0.dateKey == key }
            ) {
              onDeleteDate(day)
            }
          },
          onInsertPrevious: {
            onInsertDate(previousKey)
          },
          onInsertNext: {
            onInsertDate(nextKey)
          }
        )
      }

      // Goals header
      Text("Goals")
        .font(.caption)
        .fontWeight(.semibold)
        .frame(
          width: goalColumnWidth,
          height: cellSize
        )

      // Today and any explicitly added future dates.
      WindowedDayColumns(
        keys: currentAndFutureDateKeys, range: futureRange
      ) { key in
        let previousKey = DayBoundary.yesterdayKey(from: key)
        let nextKey = DayBoundary.tomorrowKey(from: key)
        DateHeaderView(
          dateKey: key,
          isSelected: key == selectedDateKey,
          canDelete: key != effectiveTodayKey,
          canInsertPrevious: !visibleDateKeySet
            .contains(previousKey),
          canInsertNext: !visibleDateKeySet.contains(nextKey),
          onTap: { onSelectDate(key) },
          onDelete: {
            if let day = visibleDays.first(
              where: { $0.dateKey == key }
            ) {
              onDeleteDate(day)
            }
          },
          onInsertPrevious: {
            onInsertDate(previousKey)
          },
          onInsertNext: {
            onInsertDate(nextKey)
          }
        )
      }
    }
    .frame(height: cellSize)
    .background(Color.secondary.opacity(0.25))
  }

  // MARK: - Add Goal Button

  @ViewBuilder
  private func addGoalButton(
    fillWidth: CGFloat
  ) -> some View {
    HStack(spacing: 0) {
      if fillWidth > 0 {
        Color.clear.frame(
          width: fillWidth, height: cellSize
        )
      }

      Color.clear.frame(
        width: CGFloat(pastDateKeys.count) * cellSize,
        height: cellSize
      )

      // Tapping adds a goal; long pressing unarchives one,
      // which lands right here at the bottom of the grid.
      Button {
        addGoal()
      } label: {
        Image(systemName: "plus")
          .font(.title2)
          .frame(
            width: goalColumnWidth,
            height: cellSize
          )
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("addGoalButton")
      .contextMenu {
        Button {
          onShowArchive?()
        } label: {
          Label(
            "Restore Archived Goal",
            systemImage: "archivebox"
          )
        }
      }

      Color.clear.frame(
        width: CGFloat(currentAndFutureDateKeys.count)
          * cellSize,
        height: cellSize
      )
    }
  }

  // MARK: - Helpers

  private func addGoal() {
    let maxOrder = goals.map(\.sortOrder).max() ?? -1
    let goal = Goal(name: "", sortOrder: maxOrder + 1)
    modelContext.insert(goal)
    newGoalId = goal.id
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      if newGoalId == goal.id { newGoalId = nil }
    }
  }

  private func archive(_ goal: Goal) {
    do {
      try withAnimation {
        try GoalArchive.archive(
          goal,
          in: modelContext
        )
      }
    } catch {
      assertionFailure(
        "Could not archive goal: \(error)"
      )
    }
  }

  private func updateSpawnTomorrowOverscroll(
    _ overscroll: CGFloat
  ) {
    guard !hasTomorrow else {
      resetSpawnTomorrowProgress()
      return
    }

    if overscroll > spawnTomorrowThreshold {
      isOverscrollingRight = true
      if spawnTomorrowTask == nil && !isSpawnTomorrowReady {
        startSpawnTomorrowProgress()
      }
    } else if isSpawnTomorrowReady
      && isInteractingWithGrid
      && overscroll < spawnTomorrowCancelThreshold {
      resetSpawnTomorrowProgress()
    } else if isSpawnTomorrowReady {
      isOverscrollingRight =
        overscroll > spawnTomorrowCancelThreshold
    } else {
      resetSpawnTomorrowProgress()
    }
  }

  private func startSpawnTomorrowProgress() {
    guard spawnTomorrowTask == nil else { return }
    spawnTomorrowProgress = 0
    isSpawnTomorrowReady = false

    spawnTomorrowTask = Task {
      let start = Date()
      while !Task.isCancelled {
        let elapsed = Date().timeIntervalSince(start)
        let progress = min(
          elapsed / spawnTomorrowHoldDuration,
          1
        )
        await MainActor.run {
          spawnTomorrowProgress = progress
          if progress >= 1 {
            isSpawnTomorrowReady = true
          }
        }
        if progress >= 1 { break }
        try? await Task.sleep(for: .milliseconds(16))
      }
    }
  }

  private func resetSpawnTomorrowProgress() {
    spawnTomorrowTask?.cancel()
    spawnTomorrowTask = nil
    isOverscrollingRight = false
    spawnTomorrowProgress = 0
    isSpawnTomorrowReady = false
  }

  private func moveGoal(
    from sourceId: UUID,
    to destinationId: UUID
  ) {
    guard sourceId != destinationId,
      let sourceIndex = goals.firstIndex(
        where: { $0.id == sourceId }
      ),
      let destinationIndex = goals.firstIndex(
        where: { $0.id == destinationId }
      )
    else { return }

    var reordered = goals
    let movedGoal = reordered.remove(at: sourceIndex)
    reordered.insert(movedGoal, at: destinationIndex)

    for (index, goal) in reordered.enumerated() {
      goal.sortOrder = index
    }
  }
}
