import SwiftUI
import SwiftData

struct IntentionView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.scenePhase) private var scenePhase
  let dateKey: String
  let todayKey: String
  var isFocused: FocusState<Bool>.Binding

  @Query private var days: [Day]
  @State private var text: String = ""

  init(
    dateKey: String,
    todayKey: String,
    isFocused: FocusState<Bool>.Binding
  ) {
    self.dateKey = dateKey
    self.todayKey = todayKey
    self.isFocused = isFocused
    let key = dateKey
    _days = Query(
      filter: #Predicate<Day> {
        $0.dateKey == key
      }
    )
  }

  private var day: Day? {
    days.max {
      ($0.intentionUpdatedAt ?? .distantPast)
        < ($1.intentionUpdatedAt ?? .distantPast)
    }
  }

  /// Date keys are `yyyy-MM-dd`, so string order matches date order.
  private var promptText: LocalizedStringKey {
    if dateKey == todayKey {
      "Today I will..."
    } else if dateKey < todayKey {
      "That day I wanted to..."
    } else {
      "That day I will..."
    }
  }

  var body: some View {
    VStack(spacing: 8) {
      Text(promptText)
        .font(.subheadline)
        .foregroundStyle(.secondary)

      TextField(
        "set an intention",
        text: $text,
        axis: .vertical
      )
      .font(.title)
      .multilineTextAlignment(.center)
      .focused(isFocused)
      .accessibilityIdentifier("intentionField")
      .onSubmit {
        isFocused.wrappedValue = false
      }
      .onAppear {
        text = day?.intentionText ?? ""
      }
      .onChange(of: day?.intentionText) { _, newValue in
        guard !isFocused.wrappedValue else { return }
        text = newValue ?? ""
      }
    }
    .padding(.horizontal)
    .padding(.vertical, 24)
    .contentShape(Rectangle())
    .onTapGesture {
      // Tapping the background around the text field
      // dismisses the keyboard
      isFocused.wrappedValue = false
    }
    .task(id: text) {
      do {
        try await Task.sleep(for: .milliseconds(500))
      } catch {
        return
      }
      saveIntention(text)
    }
    .onChange(of: isFocused.wrappedValue) { _, focused in
      if !focused {
        saveIntention(text)
      }
    }
    .onChange(of: scenePhase) { _, newPhase in
      if newPhase != .active {
        saveIntention(text)
      }
    }
    .onDisappear {
      saveIntention(text)
    }
  }

  private func saveIntention(_ newText: String) {
    if !days.isEmpty {
      guard days.contains(where: {
        $0.intentionText != newText
      }) else {
        return
      }

      let now = Date()
      for day in days {
        day.intentionText = newText
        day.intentionUpdatedAt = now
      }
    } else if !newText.isEmpty {
      let newDay = Day(
        dateKey: dateKey,
        intentionText: newText
      )
      modelContext.insert(newDay)
    }
  }
}
