import SwiftUI
import SwiftData

struct IntentionView: View {
  @Environment(\.modelContext) private var modelContext
  let dateKey: String
  let isToday: Bool
  var isFocused: FocusState<Bool>.Binding

  @Query private var intentions: [Intention]
  @State private var text: String = ""

  init(
    dateKey: String,
    isToday: Bool,
    isFocused: FocusState<Bool>.Binding
  ) {
    self.dateKey = dateKey
    self.isToday = isToday
    self.isFocused = isFocused
    let key = dateKey
    _intentions = Query(
      filter: #Predicate<Intention> {
        $0.dateKey == key
      },
      sort: \Intention.updatedAt,
      order: .reverse
    )
  }

  private var intention: Intention? {
    intentions.first
  }

  var body: some View {
    VStack(spacing: 8) {
      Text(
        isToday
          ? "Today I will..."
          : "That day I will..."
      )
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
      .onChange(of: text) { _, newValue in
        saveIntention(newValue)
      }
      .onAppear {
        text = intention?.text ?? ""
      }
      .onChange(of: intentions) {
        text = intention?.text ?? ""
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
  }

  private func saveIntention(_ newText: String) {
    if intention != nil {
      let now = Date()
      for intention in intentions {
        intention.text = newText
        intention.updatedAt = now
      }
    } else if !newText.isEmpty {
      let newIntention = Intention(
        dateKey: dateKey,
        text: newText
      )
      modelContext.insert(newIntention)
    }
  }
}
