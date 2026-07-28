import Foundation

enum DayBoundary {
  private static let formatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
  }()

  /// Returns the "logical date key" for a given instant.
  /// Before 4:00 AM local time, returns yesterday's date.
  static func dateKey(
    for date: Date = .now,
    calendar: Calendar = .current
  ) -> String {
    let hour = calendar.component(.hour, from: date)
    let adjusted = hour < 4
      ? calendar.date(byAdding: .day, value: -1, to: date)!
      : date
    return formatter.string(from: adjusted)
  }

  /// Formats a calendar date without applying the 4:00 AM
  /// logical-day boundary.
  static func calendarDateKey(for date: Date) -> String {
    formatter.string(from: date)
  }

  /// Returns the dateKey for tomorrow relative to a given key.
  static func tomorrowKey(from key: String) -> String {
    guard let date = formatter.date(from: key) else {
      return key
    }
    let tomorrow = Calendar.current.date(
      byAdding: .day, value: 1, to: date
    )!
    return formatter.string(from: tomorrow)
  }

  /// Returns the dateKey for yesterday relative to a given key.
  static func yesterdayKey(from key: String) -> String {
    guard let date = formatter.date(from: key) else {
      return key
    }
    let yesterday = Calendar.current.date(
      byAdding: .day, value: -1, to: date
    )!
    return formatter.string(from: yesterday)
  }

  /// Returns the latest visible date on or after the calendar
  /// day, falling back to the calendar day itself.
  static func effectiveTodayKey(
    calendarTodayKey: String,
    visibleDateKeys: [String]
  ) -> String {
    visibleDateKeys
      .filter { $0 >= calendarTodayKey }
      .max() ?? calendarTodayKey
  }

  /// Parses a dateKey back to a Date (at noon) for display.
  static func displayDate(for key: String) -> Date? {
    formatter.date(from: key)
  }

  /// Formats a dateKey for display, e.g. "Mon\n3/16"
  static func displayString(for key: String) -> String {
    guard let date = displayDate(for: key) else { return key }
    let dayOfWeek = DateFormatter()
    dayOfWeek.dateFormat = "EEE"
    let monthDay = DateFormatter()
    monthDay.dateFormat = "M/d"
    return "\(dayOfWeek.string(from: date))\n\(monthDay.string(from: date))"
  }
}
