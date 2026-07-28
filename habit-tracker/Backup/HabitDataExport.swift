import Foundation

struct HabitDataExport: Codable, Sendable {
  static let currentFormatVersion = 1
  static let currentModelSchemaVersion = "3.0.0"

  let formatVersion: Int
  let modelSchemaVersion: String
  let exportedAt: Date
  let dateRange: DateRange
  let goals: [GoalRecord]
  let days: [DayRecord]
  let completions: [CompletionRecord]

  struct DateRange: Codable, Sendable {
    let start: String
    let end: String
  }

  struct GoalRecord: Codable, Sendable {
    let id: UUID
    let name: String
    let sortOrder: Int
    let createdAt: Date
    let isDeleted: Bool
    let nameHistoryJSON: String
    let nameHistory: [NameHistoryRecord]
  }

  struct NameHistoryRecord: Codable, Sendable {
    let oldName: String
    let changedAt: Date
  }

  struct DayRecord: Codable, Sendable {
    let id: UUID
    let dateKey: String
    let isHidden: Bool
    let createdAt: Date
    let intentionText: String
    let intentionUpdatedAt: Date?
  }

  struct CompletionRecord: Codable, Sendable {
    let id: UUID
    let dateKey: String
    let isCompleted: Bool
    let updatedAt: Date
    let goalID: UUID?
  }

  @MainActor
  static func make(
    goals: [Goal],
    days: [Day],
    completions: [Completion],
    startDateKey: String,
    endDateKey: String,
    exportedAt: Date = .now
  ) -> HabitDataExport {
    let orderedBounds = [
      startDateKey,
      endDateKey,
    ].sorted()
    let start = orderedBounds[0]
    let end = orderedBounds[1]

    return HabitDataExport(
      formatVersion: currentFormatVersion,
      modelSchemaVersion: currentModelSchemaVersion,
      exportedAt: exportedAt,
      dateRange: DateRange(
        start: start,
        end: end
      ),
      goals: goals
        .map(GoalRecord.init)
        .sorted {
          if $0.sortOrder == $1.sortOrder {
            return $0.id.uuidString < $1.id.uuidString
          }
          return $0.sortOrder < $1.sortOrder
        },
      days: days
        .filter {
          $0.dateKey >= start && $0.dateKey <= end
        }
        .map(DayRecord.init)
        .sorted {
          if $0.dateKey == $1.dateKey {
            return $0.id.uuidString < $1.id.uuidString
          }
          return $0.dateKey < $1.dateKey
        },
      completions: completions
        .filter {
          $0.dateKey >= start && $0.dateKey <= end
        }
        .map(CompletionRecord.init)
        .sorted {
          if $0.dateKey == $1.dateKey {
            return $0.id.uuidString < $1.id.uuidString
          }
          return $0.dateKey < $1.dateKey
        }
    )
  }

  func encodedJSON() throws -> Data {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = [
      .prettyPrinted,
      .sortedKeys,
      .withoutEscapingSlashes,
    ]
    return try encoder.encode(self)
  }

  var suggestedFilename: String {
    "habit-tracker-\(dateRange.start)-to-\(dateRange.end).json"
  }
}

private extension HabitDataExport.GoalRecord {
  @MainActor
  init(_ goal: Goal) {
    id = goal.id
    name = goal.name
    sortOrder = goal.sortOrder
    createdAt = goal.createdAt
    isDeleted = goal.isDeleted
    nameHistoryJSON = goal.nameHistoryJSON
    nameHistory = goal.nameHistory.map {
      HabitDataExport.NameHistoryRecord(
        oldName: $0.oldName,
        changedAt: $0.changedAt
      )
    }
  }
}

private extension HabitDataExport.DayRecord {
  @MainActor
  init(_ day: Day) {
    id = day.id
    dateKey = day.dateKey
    isHidden = day.isHidden
    createdAt = day.createdAt
    intentionText = day.intentionText
    intentionUpdatedAt = day.intentionUpdatedAt
  }
}

private extension HabitDataExport.CompletionRecord {
  @MainActor
  init(_ completion: Completion) {
    id = completion.id
    dateKey = completion.dateKey
    isCompleted = completion.isCompleted
    updatedAt = completion.updatedAt
    goalID = completion.goal?.id
  }
}
