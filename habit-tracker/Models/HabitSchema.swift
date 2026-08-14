import Foundation
import SwiftData

enum HabitSchemaV1: VersionedSchema {
  static let versionIdentifier =
    Schema.Version(1, 0, 0)

  static let models: [any PersistentModel.Type] = [
    Goal.self,
    Completion.self,
    Intention.self,
    Day.self,
  ]

  @Model
  final class Goal {
    var id: UUID = UUID()
    var name: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var isDeleted: Bool = false
    var nameHistoryJSON: String = "[]"

    @Relationship(
      deleteRule: .cascade,
      inverse: \Completion.goal
    )
    var completions: [Completion]? = []

    init(name: String = "", sortOrder: Int = 0) {
      self.id = UUID()
      self.name = name
      self.sortOrder = sortOrder
      self.createdAt = Date()
    }
  }

  @Model
  final class Completion {
    var id: UUID = UUID()
    var dateKey: String = ""
    var isCompleted: Bool = true
    var updatedAt: Date = Date()
    var goal: Goal?

    init(dateKey: String, goal: Goal) {
      self.id = UUID()
      self.dateKey = dateKey
      self.isCompleted = true
      self.updatedAt = Date()
      self.goal = goal
    }
  }

  @Model
  final class Intention {
    var id: UUID = UUID()
    var dateKey: String = ""
    var text: String = ""
    var updatedAt: Date = Date()

    init(dateKey: String, text: String = "") {
      self.id = UUID()
      self.dateKey = dateKey
      self.text = text
      self.updatedAt = Date()
    }
  }

  @Model
  final class Day {
    var id: UUID = UUID()
    var dateKey: String = ""
    var isHidden: Bool = false
    var createdAt: Date = Date()

    init(dateKey: String) {
      self.id = UUID()
      self.dateKey = dateKey
      self.createdAt = Date()
    }
  }
}

enum HabitSchemaV2: VersionedSchema {
  static let versionIdentifier =
    Schema.Version(2, 0, 0)

  static let models: [any PersistentModel.Type] = [
    Goal.self,
    Completion.self,
    Intention.self,
    Day.self,
  ]

  @Model
  final class Goal {
    var id: UUID = UUID()
    var name: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var isDeleted: Bool = false
    var nameHistoryJSON: String = "[]"

    @Relationship(
      deleteRule: .cascade,
      inverse: \Completion.goal
    )
    var completions: [Completion]? = []

    init(name: String = "", sortOrder: Int = 0) {
      self.id = UUID()
      self.name = name
      self.sortOrder = sortOrder
      self.createdAt = Date()
    }
  }

  @Model
  final class Completion {
    var id: UUID = UUID()
    var dateKey: String = ""
    var isCompleted: Bool = true
    var updatedAt: Date = Date()
    var goal: Goal?

    init(dateKey: String, goal: Goal) {
      self.id = UUID()
      self.dateKey = dateKey
      self.isCompleted = true
      self.updatedAt = Date()
      self.goal = goal
    }
  }

  @Model
  final class Intention {
    var id: UUID = UUID()
    var dateKey: String = ""
    var text: String = ""
    var updatedAt: Date = Date()

    init(dateKey: String, text: String = "") {
      self.id = UUID()
      self.dateKey = dateKey
      self.text = text
      self.updatedAt = Date()
    }
  }

  @Model
  final class Day {
    var id: UUID = UUID()
    var dateKey: String = ""
    var isHidden: Bool = false
    var createdAt: Date = Date()
    var intentionText: String = ""
    var intentionUpdatedAt: Date?

    init(
      dateKey: String,
      intentionText: String,
      intentionUpdatedAt: Date
    ) {
      self.id = UUID()
      self.dateKey = dateKey
      self.createdAt = Date()
      self.intentionText = intentionText
      self.intentionUpdatedAt = intentionUpdatedAt
    }
  }
}

enum HabitSchemaV3: VersionedSchema {
  static let versionIdentifier =
    Schema.Version(3, 0, 0)

  static let models: [any PersistentModel.Type] = [
    Goal.self,
    Completion.self,
    Day.self,
  ]

  @Model
  final class Goal {
    var id: UUID = UUID()
    var name: String = ""
    var sortOrder: Int = 0
    var createdAt: Date = Date()
    var isDeleted: Bool = false
    var nameHistoryJSON: String = "[]"

    @Relationship(
      deleteRule: .cascade,
      inverse: \Completion.goal
    )
    var completions: [Completion]? = []

    init(name: String = "", sortOrder: Int = 0) {
      self.id = UUID()
      self.name = name
      self.sortOrder = sortOrder
      self.createdAt = Date()
    }
  }

  @Model
  final class Completion {
    var id: UUID = UUID()
    var dateKey: String = ""
    var isCompleted: Bool = true
    var updatedAt: Date = Date()
    var goal: Goal?

    init(dateKey: String, goal: Goal) {
      self.id = UUID()
      self.dateKey = dateKey
      self.isCompleted = true
      self.updatedAt = Date()
      self.goal = goal
    }
  }

  @Model
  final class Day {
    var id: UUID = UUID()
    var dateKey: String = ""
    var isHidden: Bool = false
    var createdAt: Date = Date()
    var intentionText: String = ""
    var intentionUpdatedAt: Date?

    init(dateKey: String) {
      self.id = UUID()
      self.dateKey = dateKey
      self.createdAt = Date()
    }
  }
}

enum HabitSchemaV4: VersionedSchema {
  static let versionIdentifier =
    Schema.Version(4, 0, 0)

  static let models: [any PersistentModel.Type] = [
    Goal.self,
    Completion.self,
    Day.self,
  ]
}

enum HabitSchemaMigrationPlan: SchemaMigrationPlan {
  static let schemas: [any VersionedSchema.Type] = [
    HabitSchemaV1.self,
    HabitSchemaV2.self,
    HabitSchemaV3.self,
    HabitSchemaV4.self,
  ]

  static let stages: [MigrationStage] = [
    .custom(
      fromVersion: HabitSchemaV1.self,
      toVersion: HabitSchemaV2.self,
      willMigrate: nil
    ) { context in
      var days = try context.fetch(
        FetchDescriptor<HabitSchemaV2.Day>()
      )
      let intentions = try context.fetch(
        FetchDescriptor<HabitSchemaV2.Intention>()
      ).sorted {
        $0.updatedAt < $1.updatedAt
      }

      for intention in intentions {
        let matchingDays = days.filter {
          $0.dateKey == intention.dateKey
        }

        if matchingDays.isEmpty {
          let day = HabitSchemaV2.Day(
            dateKey: intention.dateKey,
            intentionText: intention.text,
            intentionUpdatedAt: intention.updatedAt
          )
          context.insert(day)
          days.append(day)
        } else {
          for day in matchingDays {
            day.intentionText = intention.text
            day.intentionUpdatedAt = intention.updatedAt
          }
        }
      }

      try context.save()
    },
    .lightweight(
      fromVersion: HabitSchemaV2.self,
      toVersion: HabitSchemaV3.self
    ),
    .lightweight(
      fromVersion: HabitSchemaV3.self,
      toVersion: HabitSchemaV4.self
    ),
  ]
}
