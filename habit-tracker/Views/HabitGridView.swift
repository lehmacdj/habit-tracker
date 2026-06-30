import SwiftUI
import SwiftData

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
  @State private var didOverscrollRight = false

  private var hasTomorrow: Bool {
    let tomorrow = DayBoundary.tomorrowKey(
      from: DayBoundary.dateKey()
    )
    return visibleDays.contains { $0.dateKey == tomorrow }
  }

  private var pastDateKeys: [String] {
    visibleDays
      .map(\.dateKey)
      .filter { $0 < effectiveTodayKey }
      .sorted()
  }

  private var todayDateKey: String { effectiveTodayKey }

  private let cellSize: CGFloat = 48
  private let goalColumnWidth: CGFloat = 160
  private let spawnTomorrowThreshold: CGFloat = 30

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
        didOverscrollRight =
          !hasTomorrow && overscroll > spawnTomorrowThreshold
      }
      .onScrollPhaseChange { oldPhase, newPhase in
        // Dismiss keyboard when scrolling begins
        if newPhase == .interacting {
          onGridTapped?()
        }
        if oldPhase == .interacting
          && didOverscrollRight {
          didOverscrollRight = false
          onSpawnTomorrow()
        }
      }
      .overlay(alignment: .trailing) {
        if didOverscrollRight && !hasTomorrow {
          VStack(spacing: 4) {
            Image(systemName: "arrow.left")
            Text("Tomorrow")
              .font(.caption2)
          }
          .foregroundStyle(.secondary)
          .padding(.trailing, 8)
        }
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
        }
      )
      .frame(width: goalColumnWidth)

      CompletionCellView(
        goal: goal,
        dateKey: todayDateKey,
        cellAge: cellAge(for: todayDateKey)
      )
    }
    .frame(minHeight: cellSize)
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
}
