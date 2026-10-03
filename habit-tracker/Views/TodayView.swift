import SwiftUI
import SwiftData

struct TodayView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let goals: [Goal]
  let days: [Day]
  let completions: [Completion]
  let dateKey: String
  let onShowGrid: () -> Void
  let onShowArchive: () -> Void
  let onReadyChanged: (Bool) -> Void

  @FocusState private var isIntentionFocused: Bool
  @State private var hasContinued = false
  @State private var showFinished = false
  @State private var newGoalID: UUID?
  @State private var noteGoal: Goal?
  @State private var pendingNote: (Goal, String)?
  @State private var editError: String?
  @State private var celebrationTrigger = 0
  @AppStorage("todayCelebrationSignature") private var celebrationSignature = ""

  private var byGoal: [UUID: Completion] {
    TodayHabits.latestByGoal(completions)
  }

  private var finishedCount: Int {
    goals.filter { (byGoal[$0.id]?.state ?? .unmarked) != .unmarked }.count
  }

  private var allFinished: Bool {
    !goals.isEmpty && finishedCount == goals.count
  }

  private var visibleGoals: [Goal] {
    goals.filter {
      showFinished || (byGoal[$0.id]?.state ?? .unmarked) == .unmarked
    }
  }

  private var signature: String {
    TodayHabits.signature(dateKey: dateKey, goals: goals, records: byGoal)
  }

  private var continueAction: (() -> Void)? {
    hasContinued ? nil : { continueToHabits() }
  }

  private var content: some View {
    GeometryReader { geometry in
      ScrollView {
        VStack(spacing: 0) {
          if !hasContinued { Spacer(minLength: 0) }
          IntentionView(
            dateKey: dateKey, todayKey: dateKey,
            isFocused: $isIntentionFocused,
            onContinue: continueAction,
            verticalPadding: 12
          )
          if hasContinued {
            checklist
          } else {
            Spacer(minLength: 0)
          }
        }
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .frame(minHeight: hasContinued ? nil : geometry.size.height)
      }
      .scrollDismissesKeyboard(.interactively)
      .accessibilityIdentifier(
        hasContinued ? "todayChecklist" : "todayIntentionPrompt"
      )
    }
  }

  var body: some View {
    content
    .onAppear {
      hasContinued = TodayHabits.intentionIsSatisfied(days)
      onReadyChanged(hasContinued)
    }
    .onChange(of: TodayHabits.intentionIsSatisfied(days)) { _, satisfied in
      // A synced intention can satisfy the prompt, but typing must not
      // make the checklist appear beneath the keyboard before Continue.
      if satisfied && !isIntentionFocused {
        hasContinued = true
        onReadyChanged(true)
      }
    }
    .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { value in
      guard hasContinued,
        value.translation.width < -80,
        abs(value.translation.width) > abs(value.translation.height) * 2
      else { return }
      isIntentionFocused = false
      onShowGrid()
    })
    .sheet(item: $noteGoal, onDismiss: savePendingNote) { goal in
      CompletionNoteEditor(
        goalName: goal.name, dateKey: dateKey,
        initialText: byGoal[goal.id]?.note ?? "",
        onSave: { pendingNote = (goal, $0) }
      )
    }
    .alert("Could Not Save Change", isPresented: Binding(
      get: { editError != nil },
      set: { if !$0 { editError = nil } }
    )) {
      Button("OK") { editError = nil }
    } message: {
      Text(editError ?? "Please try again.")
    }
  }

  private var checklist: some View {
    LazyVStack(spacing: 6) {
      if goals.isEmpty {
        ContentUnavailableView(
          "Your day starts here", systemImage: "checklist",
          description: Text("Add a habit to start your daily checklist.")
        )
      } else if allFinished {
        VStack(spacing: 12) {
          if celebrationSignature == signature {
            Image(systemName: "party.popper.fill")
              .font(.system(size: 64))
              .foregroundStyle(.orange, .pink)
              .symbolEffect(
                .bounce, options: .nonRepeating,
                value: reduceMotion ? 0 : celebrationTrigger
              )
              .accessibilityIdentifier("todayCelebration")
              .accessibilityLabel("Celebration")
          }
          Text("All done for today")
            .font(.title2.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
      }

      ForEach(visibleGoals) { goal in
        habitRow(goal)
          .transition(.opacity)
      }

      Button {
        isIntentionFocused = false
        let goal = GoalEditing.add(to: goals, in: modelContext)
        newGoalID = goal.id
        Task { @MainActor in
          try? await Task.sleep(for: .seconds(1))
          if newGoalID == goal.id { newGoalID = nil }
        }
      } label: {
        Label("Add habit", systemImage: "plus")
          .frame(maxWidth: .infinity, minHeight: 44)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .accessibilityIdentifier("addGoalButton")
      .contextMenu {
        Button("Restore Archived Goal", systemImage: "archivebox") {
          onShowArchive()
        }
      }
      .dropDestination(for: HabitDragItem.self) { items, _ in
        move(items.map(\.id), before: nil)
      }

      if finishedCount > 0 {
        Button {
          withAnimation(.easeInOut(duration: 0.2)) {
            showFinished.toggle()
          }
        } label: {
          Label(
            showFinished ? "Hide finished" : "Show finished (\(finishedCount))",
            systemImage: showFinished ? "eye.slash" : "eye"
          )
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .padding(.vertical, 8)
        .accessibilityIdentifier("toggleFinishedButton")
      }
    }
    .padding(.horizontal, 12)
    .padding(.bottom, 12)
  }

  private func habitRow(_ goal: Goal) -> some View {
    let records = completions.filter { $0.goal?.id == goal.id }
    return HStack(spacing: 8) {
      Image(systemName: "line.3.horizontal")
        .foregroundStyle(.tertiary)
        .frame(width: 44, height: 48)
        .contentShape(Rectangle())
        .draggable(HabitDragItem(id: goal.id.uuidString)) {
          Text(goal.name.isEmpty ? "Untitled habit" : goal.name)
            .padding()
            .background(.background)
        }
        .accessibilityLabel("Reorder \(goal.name)")
        .accessibilityIdentifier("reorder-\(goal.id)")
        .accessibilityAction(named: "Move up") { moveUp(goal) }
        .accessibilityAction(named: "Move down") { moveDown(goal) }
      GoalNameView(
        goal: goal, streakLength: nil,
        startEditing: goal.id == newGoalID,
        onArchive: { archive(goal) },
        textAlignment: .leading
      )
      CompletionCellView(
        completions: records, goal: goal, dateKey: dateKey,
        allowsTapToComplete: true,
        onEditNote: {
          isIntentionFocused = false
          noteGoal = goal
        },
        isChecklist: true,
        onMarked: { previous, current in
          didMark(current, wasUnfinished: previous == .unmarked)
        }
      )
    }
    .padding(4)
    .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 16))
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("todayHabit-\(goal.id)")
    .dropDestination(for: HabitDragItem.self) { items, _ in
      move(items.map(\.id), before: goal.id)
    }
  }

  private func continueToHabits() {
    do {
      try modelContext.save()
      isIntentionFocused = false
      hasContinued = true
      onReadyChanged(true)
    } catch {
      editError = "Your intention could not be saved. " + error.localizedDescription
    }
  }

  private func didMark(_ state: CompletionState, wasUnfinished: Bool) {
    // Fetch after the edit so even the final new record is included before
    // SwiftData delivers the next @Query update. Notes never trigger this.
    do {
      let key = dateKey
      let records = try modelContext.fetch(FetchDescriptor<Completion>(
        predicate: #Predicate { $0.dateKey == key }
      ))
      let latest = TodayHabits.latestByGoal(records)
      let states = goals.map { latest[$0.id]?.state ?? .unmarked }
      if TodayHabits.shouldCelebrate(states: states, finalMark: state) {
        celebrationSignature = TodayHabits.signature(
          dateKey: dateKey, goals: goals, records: latest
        )
        if wasUnfinished {
          Task { @MainActor in
            // Give the celebratory graphic time to enter the view tree.
            try? await Task.sleep(for: .milliseconds(120))
            celebrationTrigger += 1
          }
        }
      } else {
        celebrationSignature = ""
      }
    } catch {
      editError = "The updated habits could not be read. " + error.localizedDescription
    }
  }

  private func move(_ items: [String], before destination: UUID?) -> Bool {
    guard let source = items.compactMap(UUID.init).first,
      goals.contains(where: { $0.id == source })
    else { return false }
    withAnimation { GoalOrdering.move(source, before: destination, in: goals) }
    return true
  }

  private func moveUp(_ goal: Goal) {
    guard let index = visibleGoals.firstIndex(where: { $0.id == goal.id }),
      index > 0 else { return }
    _ = move([goal.id.uuidString], before: visibleGoals[index - 1].id)
  }

  private func moveDown(_ goal: Goal) {
    guard let index = visibleGoals.firstIndex(where: { $0.id == goal.id }),
      index + 1 < visibleGoals.count else { return }
    let next = visibleGoals[index + 1]
    guard let fullIndex = goals.firstIndex(where: { $0.id == next.id })
    else { return }
    let destination = fullIndex + 1 < goals.count ? goals[fullIndex + 1].id : nil
    _ = move([goal.id.uuidString], before: destination)
  }

  private func archive(_ goal: Goal) {
    do {
      try GoalArchive.archive(goal, in: modelContext)
    } catch {
      editError = "The habit could not be archived. " + error.localizedDescription
    }
  }

  private func savePendingNote() {
    guard let (goal, text) = pendingNote else { return }
    pendingNote = nil
    do {
      try CompletionRecords.saveNote(
        text, goal: goal, dateKey: dateKey, in: modelContext
      )
      try modelContext.save()
    } catch {
      editError = "The note could not be saved. " + error.localizedDescription
    }
  }
}
