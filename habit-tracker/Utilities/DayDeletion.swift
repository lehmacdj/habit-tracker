import Foundation

enum DayDeletion {
  struct Outcome {
    let shouldEnsureTodayExists: Bool
    let selectedDateKey: String
  }

  @MainActor
  static func hide(
    dateKey: String,
    in days: [Day],
    selectedDateKey: String,
    effectiveTodayKey: String
  ) -> Outcome {
    for day in days where day.dateKey == dateKey {
      day.isHidden = true
    }

    let wasEffectiveToday =
      dateKey == effectiveTodayKey
    guard !wasEffectiveToday,
      dateKey == selectedDateKey
    else {
      return Outcome(
        shouldEnsureTodayExists: wasEffectiveToday,
        selectedDateKey: selectedDateKey
      )
    }

    let remainingKeys = Set(
      days
        .filter {
          !$0.isHidden && $0.dateKey != dateKey
        }
        .map(\.dateKey)
    )
    let nextSelection =
      remainingKeys.filter { $0 < dateKey }.max()
      ?? remainingKeys.filter { $0 > dateKey }.min()
      ?? effectiveTodayKey

    return Outcome(
      shouldEnsureTodayExists: false,
      selectedDateKey: nextSelection
    )
  }
}
