import Foundation
import WidgetKit

enum HabitWidgetSummaryStore {
  static let appGroupIdentifier =
    "group.is.devin.habit-tracker"
  static let widgetKind = "DailyGoalWidget"

  private static let intentionKey = "todayIntention"
  private static let completedCountKey = "completedCount"
  private static let updatedAtKey = "updatedAt"

  static func save(
    todayIntention: String?,
    completedCount: Int
  ) {
    let defaults = UserDefaults(
      suiteName: appGroupIdentifier
    ) ?? .standard
    defaults.set(
      todayIntention,
      forKey: intentionKey
    )
    defaults.set(
      completedCount,
      forKey: completedCountKey
    )
    defaults.set(
      Date(),
      forKey: updatedAtKey
    )
    WidgetCenter.shared.reloadTimelines(ofKind: widgetKind)
  }
}
