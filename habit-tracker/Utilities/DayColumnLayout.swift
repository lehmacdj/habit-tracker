import Foundation

struct DayColumnLayout {
  let pastDateKeys: [String]
  let currentAndFutureDateKeys: [String]
  private let todayKey: String

  init(visibleDateKeys: [String], todayKey: String) {
    self.todayKey = todayKey
    let uniqueKeys = Set(visibleDateKeys)
    pastDateKeys = uniqueKeys
      .filter { $0 < todayKey }
      .sorted()
    currentAndFutureDateKeys = [todayKey] + uniqueKeys
      .filter { $0 > todayKey }
      .sorted()
  }

  /// Single taps complete only today and yesterday. Other
  /// cells are changed through their context menu.
  func allowsTapToComplete(for dateKey: String) -> Bool {
    dateKey == todayKey
      || dateKey == DayBoundary.yesterdayKey(
        from: todayKey
      )
  }
}
