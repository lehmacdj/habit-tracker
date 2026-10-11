import Foundation
import Observation
import WatchConnectivity

@MainActor
@Observable
final class WatchTodayStore: NSObject, WCSessionDelegate {
  private(set) var cache = WatchCache()
  private(set) var isReachable = false
  var errorMessage: String?
  private let cacheURL: URL
  private let isDemo: Bool
  private var canSave = true

  init(cacheURL: URL? = nil) {
    self.cacheURL = cacheURL ?? URL.applicationSupportDirectory
      .appending(path: "watch-today.json")
    #if DEBUG
    isDemo = ProcessInfo.processInfo.arguments.contains("--watch-demo")
    #else
    isDemo = false
    #endif
    super.init()
    if isDemo {
      cache.snapshot = WatchSnapshot(today: WatchToday(
        dateKey: DayBoundary.dateKey(), intention: "",
        habits: ["Read", "Go for a walk", "Practice piano"].map {
          WatchToday.Habit(id: UUID(), name: $0, state: .unmarked)
        }
      ))
      return
    }
    do {
      if FileManager.default.fileExists(atPath: self.cacheURL.path) {
        cache = try JSONDecoder().decode(
          WatchCache.self, from: Data(contentsOf: self.cacheURL)
        )
      }
    } catch {
      canSave = false
      errorMessage = "Saved watch changes could not be read. Reopen the app "
        + "to try again. " + WatchWire.errorDescription(error)
    }
    WCSession.default.delegate = self
    WCSession.default.activate()
  }

  func today(on dateKey: String) -> WatchToday? {
    cache.snapshot?.today.applying(cache.pending, on: dateKey)
  }

  @discardableResult
  func edit(_ value: WatchEdit.Value, on dateKey: String) -> Bool {
    var updated = cache
    updated.pending.append(WatchEdit(dateKey: dateKey, value: value))
    guard save(updated) else { return false }
    flush()
    return true
  }

  func refresh() {
    guard !isDemo else { return }
    let session = WCSession.default
    isReachable = session.isReachable
    guard session.activationState == .activated else { return }
    flush()
    guard session.isReachable else { return }
    session.sendMessage(
      [WatchWire.requestKey: true], replyHandler: { response in
        Task { @MainActor in self.receive(response) }
      }, errorHandler: { _ in
        // Offline is expected. Keep the cached day and pending edits visible.
      }
    )
  }

  /// Keep the background task alive until WatchConnectivity has delivered
  /// its queued context and receipts. SwiftUI completes the task on return.
  func receiveBackgroundUpdates() async {
    guard !isDemo else { return }
    let session = WCSession.default
    repeat {
      do { try await Task.sleep(for: .milliseconds(100)) }
      catch { return }
    } while session.activationState != .activated || session.hasContentPending
    await Task.yield()
  }

  private func save(_ updated: WatchCache) -> Bool {
    guard canSave else { return false }
    do {
      if !isDemo {
        try FileManager.default.createDirectory(
          at: cacheURL.deletingLastPathComponent(),
          withIntermediateDirectories: true
        )
        try JSONEncoder().encode(updated).write(to: cacheURL, options: .atomic)
      }
      cache = updated
      return true
    } catch {
      errorMessage = "Your change could not be saved on this watch. "
        + WatchWire.errorDescription(error)
      return false
    }
  }

  private func flush() {
    guard !isDemo else { return }
    let session = WCSession.default
    guard session.activationState == .activated else { return }
    for edit in cache.pending {
      do {
        let payload = try WatchWire.encode(edit)
        let alreadyQueued = session.outstandingUserInfoTransfers.contains {
          (try? WatchWire.decode(WatchEdit.self, from: $0.userInfo).id) == edit.id
        }
        if !alreadyQueued { session.transferUserInfo(payload) }
        if session.isReachable {
          session.sendMessage(payload, replyHandler: { response in
            Task { @MainActor in self.receive(response) }
          }, errorHandler: { _ in
            // Durable transfer and local outbox both survive disconnection.
          })
        }
      } catch {
        errorMessage = "Your change could not be sent. "
          + WatchWire.errorDescription(error)
      }
    }
  }

  private func receive(_ message: [String: Any]) {
    if let error = message["error"] as? String {
      errorMessage = error
      return
    }
    do {
      let reply = try WatchWire.decode(WatchReply.self, from: message)
      var updated = cache
      updated.receive(reply)
      if save(updated) {
        for transfer in WCSession.default.outstandingUserInfoTransfers {
          if let edit = try? WatchWire.decode(WatchEdit.self, from: transfer.userInfo),
            reply.acknowledged.contains(edit.id) {
            transfer.cancel()
          }
        }
      }
    } catch {
      errorMessage = "The phone update could not be read. "
        + WatchWire.errorDescription(error)
    }
  }

  nonisolated func session(
    _ session: WCSession, activationDidCompleteWith state: WCSessionActivationState,
    error: Error?
  ) {
    Task { @MainActor in
      if let error {
        self.errorMessage = "Could not connect to your iPhone. "
          + WatchWire.errorDescription(error)
      }
      if !session.receivedApplicationContext.isEmpty {
        self.receive(session.receivedApplicationContext)
      }
      self.refresh()
    }
  }

  nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
    Task { @MainActor in self.refresh() }
  }

  nonisolated func session(
    _ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]
  ) {
    Task { @MainActor in self.receive(applicationContext) }
  }

  nonisolated func session(
    _ session: WCSession, didReceiveMessage message: [String: Any]
  ) {
    Task { @MainActor in self.receive(message) }
  }

  nonisolated func session(
    _ session: WCSession, didReceiveUserInfo userInfo: [String: Any]
  ) {
    Task { @MainActor in self.receive(userInfo) }
  }
}
