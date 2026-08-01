import Foundation

enum HabitStreak {
  struct Entry {
    let dateKey: String
    let isCompleted: Bool
    let updatedAt: Date
  }

  static let completedGreenOpacity = 0.35

  private static let startingGreenOpacity = 0.12
  private static let curveStrength = 5.0
  private static let minimumQualifyingDays = 30
  private static let fullyEstablishedDays = 90
  private static let maximumExceptions = 5

  static func currentQualifyingLength(
    entries: [Entry],
    hiddenDateKeys: Set<String>,
    effectiveTodayKey: String
  ) -> Int? {
    let completionByDate = latestEntriesByDate(entries)
    let isCurrentDayCompleted =
      completionByDate[effectiveTodayKey]?.isCompleted == true
    var dateKey = isCurrentDayCompleted
      ? effectiveTodayKey
      : DayBoundary.yesterdayKey(from: effectiveTodayKey)
    var eligibleDays = 0
    var exceptions = 0
    var longestQualifyingLength: Int?

    while exceptions <= maximumExceptions {
      if !hiddenDateKeys.contains(dateKey) {
        eligibleDays += 1
        if completionByDate[dateKey]?.isCompleted != true {
          exceptions += 1
        }

        if exceptions > maximumExceptions {
          break
        }
        if eligibleDays >= minimumQualifyingDays,
          exceptions <= exceptionAllowance(for: eligibleDays) {
          longestQualifyingLength = eligibleDays
        }
      }

      dateKey = DayBoundary.yesterdayKey(from: dateKey)
    }

    return longestQualifyingLength
  }

  static func titleGreenOpacity(
    for qualifyingLength: Int?
  ) -> Double? {
    guard let qualifyingLength,
      qualifyingLength >= minimumQualifyingDays
    else { return nil }

    let dayRange = fullyEstablishedDays - minimumQualifyingDays
    let progress = min(
      Double(qualifyingLength - minimumQualifyingDays)
        / Double(dayRange),
      1
    )
    let curvedProgress =
      (exp(curveStrength * progress) - 1)
      / (exp(curveStrength) - 1)

    return startingGreenOpacity
      + (completedGreenOpacity - startingGreenOpacity)
        * curvedProgress
  }

  private static func latestEntriesByDate(
    _ entries: [Entry]
  ) -> [String: Entry] {
    entries.reduce(into: [:]) { latest, entry in
      guard let existing = latest[entry.dateKey],
        existing.updatedAt > entry.updatedAt
      else {
        latest[entry.dateKey] = entry
        return
      }
    }
  }

  private static func exceptionAllowance(for days: Int) -> Int {
    switch days {
    case ..<minimumQualifyingDays:
      0
    case 30..<50:
      2
    case 50..<70:
      3
    case 70..<fullyEstablishedDays:
      4
    default:
      maximumExceptions
    }
  }
}
