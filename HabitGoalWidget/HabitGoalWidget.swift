import SwiftUI
import WidgetKit

struct DailyGoalEntry: TimelineEntry {
  let date: Date
  let intention: String?
  let completedCount: Int
}

struct DailyGoalProvider: TimelineProvider {
  func placeholder(in context: Context) -> DailyGoalEntry {
    DailyGoalEntry(
      date: Date(),
      intention: "Drink water before coffee",
      completedCount: 2
    )
  }

  func getSnapshot(
    in context: Context,
    completion: @escaping (DailyGoalEntry) -> Void
  ) {
    completion(loadEntry())
  }

  func getTimeline(
    in context: Context,
    completion: @escaping (Timeline<DailyGoalEntry>) -> Void
  ) {
    let nextRefresh = Calendar.current.date(
      byAdding: .minute,
      value: 15,
      to: Date()
    ) ?? Date().addingTimeInterval(15 * 60)

    completion(Timeline(
      entries: [loadEntry()],
      policy: .after(nextRefresh)
    ))
  }

  private func loadEntry() -> DailyGoalEntry {
    let defaults = UserDefaults(
      suiteName: WidgetSummary.appGroupIdentifier
    ) ?? .standard
    let rawIntention = defaults.string(
      forKey: WidgetSummary.intentionKey
    )?.trimmingCharacters(in: .whitespacesAndNewlines)
    let intention = rawIntention?.isEmpty == false
      ? rawIntention
      : nil

    return DailyGoalEntry(
      date: Date(),
      intention: intention,
      completedCount: defaults.integer(
        forKey: WidgetSummary.completedCountKey
      )
    )
  }
}

struct HabitGoalWidgetView: View {
  let entry: DailyGoalEntry

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(entry.intention == nil ? "Add today's goal" : "Today")
        .font(.caption)
        .foregroundStyle(.secondary)

      Text(entry.intention ?? "What matters most?")
        .font(.headline)
        .lineLimit(3)
        .minimumScaleFactor(0.75)
        .foregroundStyle(.primary)

      Spacer(minLength: 0)

      Text("\(entry.completedCount) completed today")
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .containerBackground(for: .widget) {
      Color(.systemBackground)
    }
    .widgetURL(URL(string: "habit-tracker://today"))
  }
}

@main
struct HabitGoalWidget: Widget {
  let kind = WidgetSummary.kind

  var body: some WidgetConfiguration {
    StaticConfiguration(
      kind: kind,
      provider: DailyGoalProvider()
    ) { entry in
      HabitGoalWidgetView(entry: entry)
    }
    .configurationDisplayName("Daily Goal")
    .description("See today's goal and what you've completed.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

private enum WidgetSummary {
  static let appGroupIdentifier =
    "group.is.devin.habit-tracker"
  static let kind = "DailyGoalWidget"
  static let intentionKey = "todayIntention"
  static let completedCountKey = "completedCount"
}

#Preview(as: .systemSmall) {
  HabitGoalWidget()
} timeline: {
  DailyGoalEntry(
    date: Date(),
    intention: "Write the first draft",
    completedCount: 3
  )
  DailyGoalEntry(
    date: Date(),
    intention: nil,
    completedCount: 0
  )
}
