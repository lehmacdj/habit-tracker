#if os(iOS)
import Foundation
import SwiftData
import WatchConnectivity
import OSLog

@MainActor
final class PhoneWatchSync: NSObject, WCSessionDelegate {
  static let shared = PhoneWatchSync()
  private var container: ModelContainer?
  private let logger = Logger(
    subsystem: "is.devin.habit-tracker", category: "WatchSync"
  )

  func start(container: ModelContainer) {
    guard WCSession.isSupported(), self.container == nil else { return }
    self.container = container
    WCSession.default.delegate = self
    WCSession.default.activate()
  }

  func publish() {
    let session = WCSession.default
    guard let container, session.activationState == .activated else { return }
    guard session.isReachable
      || (session.isPaired && session.isWatchAppInstalled) else { return }
    do {
      // Save pending phone edits before advertising them as acknowledged data.
      try container.mainContext.save()
      let reply = WatchReply(
        snapshot: try WatchEdits.snapshot(in: container.mainContext)
      )
      let message = try WatchWire.encode(reply)
      if session.isReachable {
        session.sendMessage(message, replyHandler: nil) { _ in
          // Background context and the next refresh retry a failed live update.
        }
      }
      updateBackgroundContext(message)
    } catch {
      logger.error("Could not update watch: \(WatchWire.errorDescription(error))")
    }
  }

  private func receive(
    _ message: [String: Any], replyHandler: (([String: Any]) -> Void)?
  ) {
    guard let container else { return }
    do {
      try container.mainContext.save()
      let context = ModelContext(container)
      var acknowledged: [UUID] = []
      if message[WatchWire.requestKey] == nil {
        let edit = try WatchWire.decode(WatchEdit.self, from: message)
        try WatchEdits.apply(edit, in: context)
        acknowledged = [edit.id]
      }
      let reply = WatchReply(
        snapshot: try WatchEdits.snapshot(in: context),
        acknowledged: acknowledged
      )
      let payload = try WatchWire.encode(reply)
      if let replyHandler {
        replyHandler(payload)
      } else if !acknowledged.isEmpty {
        // Background edits need a durable receipt, not just transport success.
        WCSession.default.transferUserInfo(payload)
      }
      updateBackgroundContext(payload)
    } catch {
      let description = WatchWire.errorDescription(error)
      logger.error("Could not save watch edit: \(description)")
      replyHandler?(["error": "Your change could not be saved. " + description])
      // No acknowledgement: the watch retains its edit for retry.
    }
  }

  private func updateBackgroundContext(_ payload: [String: Any]) {
    let session = WCSession.default
    guard session.isPaired, session.isWatchAppInstalled else { return }
    do {
      try session.updateApplicationContext(payload)
    } catch {
      // A background transport error must neither block a live update nor
      // send a second response after an edit was already acknowledged.
      logger.error("Could not queue watch update: \(WatchWire.errorDescription(error))")
    }
  }

  nonisolated func session(
    _ session: WCSession, activationDidCompleteWith state: WCSessionActivationState,
    error: Error?
  ) {
    Task { @MainActor in self.publish() }
  }

  nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
    Task { @MainActor in self.publish() }
  }

  nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
    Task { @MainActor in self.publish() }
  }

  nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

  nonisolated func sessionDidDeactivate(_ session: WCSession) {
    session.activate()
  }

  nonisolated func session(
    _ session: WCSession, didReceiveMessage message: [String: Any],
    replyHandler: @escaping ([String: Any]) -> Void
  ) {
    Task { @MainActor in self.receive(message, replyHandler: replyHandler) }
  }

  nonisolated func session(
    _ session: WCSession, didReceiveUserInfo userInfo: [String: Any]
  ) {
    Task { @MainActor in self.receive(userInfo, replyHandler: nil) }
  }
}
#endif
