import SwiftUI

struct CloudSyncStatusView: View {
  @Environment(\.dismiss) private var dismiss
  @ObservedObject var monitor: CloudSyncMonitor

  var body: some View {
    NavigationStack {
      List {
        Section("Status") {
          Label {
            Text(monitor.accountState.title)
          } icon: {
            accountIcon
          }

          if monitor.hasActivityInProgress {
            HStack {
              ProgressView()
              Text("CloudKit activity in progress")
            }
          }

          LabeledContent("Last download") {
            Text(lastSuccess(for: .importData))
          }
          LabeledContent("Last upload") {
            Text(lastSuccess(for: .exportData))
          }

          if monitor.needsAttention {
            Text(
              "CloudKit reported a problem. The most recent "
                + "failure for each operation remains flagged "
                + "until that operation succeeds."
            )
            .foregroundStyle(.secondary)
          } else {
            Text(
              "CloudKit has not reported a current failure. "
                + "Synchronization still happens on the "
                + "system's schedule."
            )
            .foregroundStyle(.secondary)
          }
        }

        Section("Recent CloudKit Activity") {
          if monitor.events.isEmpty {
            ContentUnavailableView(
              "No Activity Yet",
              systemImage: "icloud",
              description: Text(
                "Setup, download, and upload events observed "
                  + "by this version of the app will appear here."
              )
            )
          } else {
            ForEach(monitor.events) { event in
              eventView(event)
            }
          }
        }

        Section("Actions") {
          Button {
            monitor.refreshAccountStatus()
          } label: {
            Label(
              "Check iCloud Account Again",
              systemImage: "arrow.clockwise"
            )
          }

          ShareLink(item: monitor.diagnosticsText) {
            Label(
              "Share Diagnostics",
              systemImage: "square.and.arrow.up"
            )
          }
        }

        Section("What CloudKit Exposes") {
          Text(
            "SwiftData reports setup, download, and upload "
              + "events and their errors. It does not expose a "
              + "second queryable copy of the store or a manual "
              + "force-sync operation. Mirroring handles record "
              + "changes internally rather than exposing two "
              + "copies for the app to resolve."
          )
          .foregroundStyle(.secondary)

          Text(
            "This screen only observes the existing SwiftData "
              + "sync path. It does not upload a backup or run a "
              + "second synchronization system."
          )
          .foregroundStyle(.secondary)
        }
      }
      .navigationTitle("Cloud Sync")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
    .task {
      monitor.refreshAccountStatus()
    }
    #if os(macOS)
    .frame(minWidth: 520, minHeight: 520)
    #endif
  }

  @ViewBuilder
  private var accountIcon: some View {
    switch monitor.accountState {
    case .checking:
      ProgressView()
    case .available:
      Image(systemName: "checkmark.icloud")
        .foregroundStyle(.green)
    case .unavailable:
      Image(systemName: "exclamationmark.icloud.fill")
        .foregroundStyle(.red)
    }
  }

  private func eventView(
    _ event: CloudSyncEventRecord
  ) -> some View {
    DisclosureGroup {
      VStack(alignment: .leading, spacing: 8) {
        LabeledContent("Started") {
          Text(event.startedAt.formatted(
            date: .abbreviated,
            time: .standard
          ))
        }
        if let endedAt = event.endedAt {
          LabeledContent("Finished") {
            Text(endedAt.formatted(
              date: .abbreviated,
              time: .standard
            ))
          }
        }
        if let errorDetails = event.errorDetails {
          Text(errorDetails)
            .font(.caption.monospaced())
            .textSelection(.enabled)
        }
      }
      .padding(.vertical, 4)
    } label: {
      Label {
        VStack(alignment: .leading) {
          Text(event.kind.title)
          Text(eventResult(event))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      } icon: {
        eventIcon(event)
      }
    }
  }

  @ViewBuilder
  private func eventIcon(
    _ event: CloudSyncEventRecord
  ) -> some View {
    if !event.isFinished {
      ProgressView()
    } else if event.succeeded {
      Image(systemName: "checkmark.circle.fill")
        .foregroundStyle(.green)
    } else {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.red)
    }
  }

  private func eventResult(
    _ event: CloudSyncEventRecord
  ) -> String {
    if !event.isFinished {
      return "In progress"
    }
    if event.succeeded {
      return "Succeeded " + (event.endedAt ?? event.startedAt)
        .formatted(.relative(presentation: .named))
    }
    return "Failed " + (event.endedAt ?? event.startedAt)
      .formatted(.relative(presentation: .named))
  }

  private func lastSuccess(
    for kind: CloudSyncEventRecord.Kind
  ) -> String {
    guard let event = monitor.events.first(
      where: {
        $0.kind == kind && $0.isFinished && $0.succeeded
      }
    ) else {
      return "None recorded"
    }
    return (event.endedAt ?? event.startedAt)
      .formatted(.relative(presentation: .named))
  }
}
