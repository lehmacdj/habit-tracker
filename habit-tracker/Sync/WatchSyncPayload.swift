import Foundation

/// Only daily tracking data crosses the phone/watch boundary. Notes stay on
/// the phone. Absolute edits (rather than toggles) make redelivery harmless.
struct WatchEdit: Codable, Equatable, Identifiable, Sendable {
  enum Value: Codable, Equatable, Sendable {
    case mark(goalID: UUID, state: CompletionState)
    case intention(String)
  }

  var id = UUID()
  var dateKey: String
  var updatedAt = Date()
  var value: Value
}

struct WatchToday: Codable, Equatable, Sendable {
  struct Habit: Codable, Equatable, Identifiable, Sendable {
    var id: UUID
    var name: String
    var state: CompletionState
  }

  var dateKey: String
  var intention: String
  var habits: [Habit]

  func applying(_ edits: [WatchEdit], on dateKey: String) -> WatchToday {
    var result = self
    if result.dateKey != dateKey {
      result.dateKey = dateKey
      result.intention = ""
      for index in result.habits.indices {
        result.habits[index].state = .unmarked
      }
    }
    for edit in edits.sorted(by: { $0.updatedAt < $1.updatedAt })
    where edit.dateKey == dateKey {
      switch edit.value {
      case .mark(let id, let state):
        if let index = result.habits.firstIndex(where: { $0.id == id }) {
          result.habits[index].state = state
        }
      case .intention(let text): result.intention = text
      }
    }
    return result
  }
}

struct WatchSnapshot: Codable, Equatable, Sendable {
  var generatedAt = Date()
  var today: WatchToday
}

struct WatchReply: Codable, Sendable {
  var snapshot: WatchSnapshot
  var acknowledged: [UUID] = []
}

struct WatchCache: Codable, Equatable, Sendable {
  var snapshot: WatchSnapshot?
  var pending: [WatchEdit] = []

  mutating func receive(_ reply: WatchReply) {
    // An acknowledgement is useful even if a newer snapshot arrived first.
    pending.removeAll { reply.acknowledged.contains($0.id) }
    if snapshot == nil || reply.snapshot.generatedAt >= snapshot!.generatedAt {
      snapshot = reply.snapshot
    }
  }
}

/// Version the wire format so an older companion cannot misinterpret edits.
enum WatchWire {
  static let payloadKey = "habitToday.v1"
  static let requestKey = "requestToday.v1"

  static func encode<T: Encodable>(_ value: T) throws -> [String: Any] {
    [payloadKey: try JSONEncoder().encode(value)]
  }

  static func decode<T: Decodable>(
    _ type: T.Type, from dictionary: [String: Any]
  ) throws -> T {
    guard let data = dictionary[payloadKey] as? Data else {
      throw CocoaError(.coderReadCorrupt)
    }
    return try JSONDecoder().decode(type, from: data)
  }

  static func errorDescription(_ error: Error) -> String {
    let error = error as NSError
    return "\(error.localizedDescription) (\(error.domain) \(error.code))"
  }
}
