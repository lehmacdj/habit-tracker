import SwiftUI
import WatchKit

struct WatchTodayView: View {
  @Bindable var store: WatchTodayStore
  let dateKey: String
  @State private var hasContinued = false
  @State private var showFinished = false
  @State private var isEditingIntention = false
  @State private var intentionDraft = ""

  private var today: WatchToday? { store.today(on: dateKey) }
  private var intention: String { today?.intention ?? "" }
  private var intentionIsSet: Bool {
    !intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
  private var finishedCount: Int {
    today?.habits.filter { $0.state != .unmarked }.count ?? 0
  }

  var body: some View {
    List {
      if let today {
        intentionButton
        if hasContinued {
          checklist(today)
        } else {
          Button("Continue") { hasContinued = true }
            .accessibilityIdentifier("continueIntentionButton")
        }
      } else {
        Text("Open Habit Tracker on your iPhone to load your habits.")
          .foregroundStyle(.secondary)
        Button("Try again") { store.refresh() }
      }
      if !store.cache.pending.isEmpty {
        Text(store.cache.pending.count == 1
          ? "1 change waiting for iPhone"
          : "\(store.cache.pending.count) changes waiting for iPhone")
          .font(.footnote)
          .foregroundStyle(.secondary)
      } else if today != nil && !store.isReachable {
        Text("Waiting for iPhone. Changes will sync when connected.")
          .font(.footnote)
          .foregroundStyle(.secondary)
      }
    }
    .navigationTitle("Today")
    .onAppear { hasContinued = intentionIsSet }
    .onChange(of: intentionIsSet) { _, isSet in
      if isSet && !isEditingIntention { hasContinued = true }
    }
    .sheet(isPresented: $isEditingIntention) {
      intentionEditor
    }
    .alert("Could Not Sync", isPresented: Binding(
      get: { store.errorMessage != nil },
      set: { if !$0 { store.errorMessage = nil } }
    )) {
      Button("OK") { store.errorMessage = nil }
    } message: {
      Text(store.errorMessage ?? "Please try again.")
    }
  }

  private var intentionButton: some View {
    Button {
      intentionDraft = intention
      isEditingIntention = true
    } label: {
      VStack(alignment: .leading, spacing: 4) {
        Text("Today I will…")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(intentionIsSet ? intention : "Set an intention")
          .font(.headline)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.vertical, 4)
      .contentShape(Rectangle())
    }
    .accessibilityIdentifier("editIntentionButton")
  }

  @ViewBuilder
  private func checklist(_ today: WatchToday) -> some View {
    if today.habits.isEmpty {
      Text("Add habits in Habit Tracker on your iPhone.")
        .foregroundStyle(.secondary)
    } else {
      if finishedCount == today.habits.count {
        Label("All done for today", systemImage: "checkmark.circle")
          .foregroundStyle(.green)
          .accessibilityIdentifier("todayAllFinished")
      }
      ForEach(today.habits.filter { showFinished || $0.state == .unmarked }) {
        habit in
        habitButton(habit)
      }
      if finishedCount > 0 {
        Button {
          showFinished.toggle()
        } label: {
          Text(showFinished ? "Hide finished" : "Show finished (\(finishedCount))")
            .font(.footnote)
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .accessibilityIdentifier("toggleFinishedButton")
      }
    }
  }

  private func habitButton(_ habit: WatchToday.Habit) -> some View {
    Button {
      mark(habit, as: habit.state == .unmarked ? .completed : .unmarked)
    } label: {
      HStack(spacing: 8) {
        Image(systemName: habit.state.symbol)
          .foregroundStyle(color(habit.state))
        Text(habit.name.isEmpty ? "Untitled habit" : habit.name)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 0)
      }
      .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
      .contentShape(Rectangle())
    }
    .accessibilityIdentifier("watchHabit-\(habit.name)")
    .accessibilityValue(status(habit.state))
    .accessibilityHint(habit.state == .unmarked
      ? "Double tap to complete" : "Double tap to clear mark")
    .accessibilityAction(named: "Skip") { mark(habit, as: .skipped) }
    .accessibilityAction(named: "Fail") { mark(habit, as: .failed) }
    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
      Button("Fail", systemImage: CompletionState.failed.actionSymbol) { mark(habit, as: .failed) }
        .tint(.red)
      Button("Skip", systemImage: CompletionState.skipped.actionSymbol) { mark(habit, as: .skipped) }
        .tint(.yellow)
    }
  }

  private var intentionEditor: some View {
    NavigationStack {
      List {
        TextField("Today I will…", text: $intentionDraft)
          .accessibilityIdentifier("intentionField")
        Button("Save") {
          if store.edit(.intention(intentionDraft), on: dateKey) {
            isEditingIntention = false
            if !intentionDraft.trimmingCharacters(in: .whitespacesAndNewlines)
              .isEmpty { hasContinued = true }
          }
        }
        .accessibilityIdentifier("saveIntentionButton")
        Button("Cancel") { isEditingIntention = false }
      }
      .navigationTitle("Intention")
    }
  }

  private func mark(_ habit: WatchToday.Habit, as state: CompletionState) {
    if store.edit(.mark(goalID: habit.id, state: state), on: dateKey) {
      WKInterfaceDevice.current().play(state == .completed ? .success : .click)
    }
  }

  private func color(_ state: CompletionState) -> Color {
    switch state {
    case .unmarked: .secondary
    case .completed: .green
    case .skipped: .yellow
    case .failed: .red
    }
  }

  private func status(_ state: CompletionState) -> String {
    switch state {
    case .unmarked: "Unfinished"
    case .completed: "Completed"
    case .skipped: "Skipped"
    case .failed: "Failed"
    }
  }
}
