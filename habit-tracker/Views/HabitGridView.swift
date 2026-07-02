import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct HabitGridView: View {
  @Environment(\.modelContext) private var modelContext
  let goals: [Goal]
  let visibleDays: [Day]
  let effectiveTodayKey: String
  let selectedDateKey: String
  let onSelectDate: (String) -> Void
  let onDeleteDate: (Day) -> Void
  let onSpawnTomorrow: () -> Void
  var onGridTapped: (() -> Void)? = nil

  @State private var newGoalId: UUID? = nil
  @State private var draggingGoalId: UUID? = nil
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

  private var pastDateKeys: [String] {
    let keys = visibleDays
      .map(\.dateKey)
      .filter { $0 < effectiveTodayKey }
    return Array(Set(keys))
      .sorted()
  }

  private var todayDateKey: String { effectiveTodayKey }

  private let cellSize: CGFloat = 48
  private let goalColumnWidth: CGFloat = 160
  private let spawnTomorrowThreshold: CGFloat = 30
  private let spawnTomorrowCancelThreshold: CGFloat = 12
  private let spawnTomorrowHoldDuration: TimeInterval = 1

  /// Width of the "real" content (past + goals + today)
  private var contentWidth: CGFloat {
    CGFloat(pastDateKeys.count) * cellSize
      + goalColumnWidth + cellSize
  }

  var body: some View {
    GeometryReader { geo in
      let fillWidth = max(geo.size.width - contentWidth, 0)
      ScrollView([.horizontal, .vertical]) {
        VStack(spacing: 0) {
          LazyVStack(
            spacing: 0,
            pinnedViews: [.sectionHeaders]
          ) {
            Section {
              ForEach(goals) { goal in
                goalRow(
                  goal: goal,
                  fillWidth: fillWidth
                )
                Divider()
              }
              addGoalButton(fillWidth: fillWidth)
            } header: {
              headerRow(fillWidth: fillWidth)
            }
          }
          Spacer(minLength: 0)
        }
        .frame(minHeight: geo.size.height)
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
  }

  // MARK: - Header Row

  @ViewBuilder
  private func headerRow(fillWidth: CGFloat) -> some View {
    HStack(spacing: 0) {
      // Left fill to push content right
      if fillWidth > 0 {
        Color.clear.frame(
          width: fillWidth, height: cellSize
        )
      }

      // Past date headers
      ForEach(pastDateKeys, id: \.self) { key in
        DateHeaderView(
          dateKey: key,
          isSelected: key == selectedDateKey,
          canDelete: true,
          onTap: { onSelectDate(key) },
          onDelete: {
            if let day = visibleDays.first(
              where: { $0.dateKey == key }
            ) {
              onDeleteDate(day)
            }
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

      // Today header — only deletable if it's a
      // spawned tomorrow, not the real calendar today
      DateHeaderView(
        dateKey: todayDateKey,
        isSelected: todayDateKey == selectedDateKey,
        canDelete: todayDateKey != DayBoundary.dateKey(),
        onTap: { onSelectDate(todayDateKey) },
        onDelete: {
          if let day = visibleDays.first(
            where: { $0.dateKey == todayDateKey }
          ) {
            onDeleteDate(day)
          }
        }
      )
    }
    .frame(height: cellSize)
    .background(Color(.systemGray4))
  }

  // MARK: - Goal Row

  @ViewBuilder
  private func goalRow(
    goal: Goal,
    fillWidth: CGFloat
  ) -> some View {
    HStack(spacing: 0) {
      if fillWidth > 0 {
        Color.clear.frame(
          width: fillWidth, height: cellSize
        )
      }

      ForEach(pastDateKeys, id: \.self) { key in
        CompletionCellView(
          goal: goal,
          dateKey: key,
          cellAge: cellAge(for: key)
        )
      }

      GoalNameView(
        goal: goal,
        startEditing: goal.id == newGoalId,
        onArchive: {
          withAnimation { goal.isDeleted = true }
        },
        onDrag: {
          draggingGoalId = goal.id
          return NSItemProvider(
            object: goal.id.uuidString as NSString
          )
        },
        dragPreview: {
          AnyView(GoalDragPreview(name: goal.name))
        }
      )
      .frame(width: goalColumnWidth)
      .simultaneousGesture(
        DragGesture(minimumDistance: 0)
          .onEnded { _ in
            if draggingGoalId == goal.id {
              draggingGoalId = nil
            }
          }
      )

      CompletionCellView(
        goal: goal,
        dateKey: todayDateKey,
        cellAge: cellAge(for: todayDateKey)
      )
    }
    .frame(minHeight: cellSize)
    .contentShape(Rectangle())
    .opacity(draggingGoalId == goal.id ? 0.45 : 1)
    .onDrop(
      of: [UTType.text],
      delegate: GoalDropDelegate(
        goal: goal,
        goals: goals,
        draggingGoalId: $draggingGoalId,
        moveGoal: moveGoal
      )
    )
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

      Color.clear.frame(
        width: cellSize, height: cellSize
      )
    }
  }

  // MARK: - Helpers

  private func cellAge(
    for key: String
  ) -> CompletionCellView.CellAge {
    let calendarToday = DayBoundary.dateKey()
    let calendarYesterday = DayBoundary.yesterdayKey(
      from: calendarToday
    )
    if key == effectiveTodayKey {
      return .current
    } else if key == calendarToday
      || key == calendarYesterday {
      return .yesterday
    } else {
      return .older
    }
  }

  private func addGoal() {
    let maxOrder = goals.map(\.sortOrder).max() ?? -1
    let goal = Goal(name: "", sortOrder: maxOrder + 1)
    modelContext.insert(goal)
    newGoalId = goal.id
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
      if newGoalId == goal.id { newGoalId = nil }
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

private struct GoalDragPreview: View {
  let name: String

  var body: some View {
    Text(name.isEmpty ? "untitled" : name)
      .font(.body)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(Color(.systemBackground))
      .clipShape(RoundedRectangle(cornerRadius: 6))
      .shadow(radius: 4)
  }
}

private struct GoalDropDelegate: DropDelegate {
  let goal: Goal
  let goals: [Goal]
  @Binding var draggingGoalId: UUID?
  let moveGoal: (UUID, UUID) -> Void

  func dropEntered(info: DropInfo) {
    guard let draggingGoalId else { return }
    withAnimation {
      moveGoal(draggingGoalId, goal.id)
    }
  }

  func performDrop(info: DropInfo) -> Bool {
    draggingGoalId = nil
    return true
  }

  func dropUpdated(info: DropInfo) -> DropProposal? {
    DropProposal(operation: .move)
  }
}
