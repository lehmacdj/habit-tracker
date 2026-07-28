import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct ExportDataView: View {
  @Environment(\.dismiss) private var dismiss

  @Query(sort: \Goal.sortOrder)
  private var goals: [Goal]

  @Query(sort: \Day.dateKey)
  private var days: [Day]

  @Query(sort: \Completion.dateKey)
  private var completions: [Completion]

  @State private var startDate = Date.now
  @State private var endDate = Date.now
  @State private var didLoadInitialRange = false
  @State private var exportDocument:
    HabitDataExportDocument?
  @State private var exportFilename = "habit-tracker.json"
  @State private var isExporting = false
  @State private var exportError: String?
  @State private var weeklyBackups:
    [HabitBackupStore.BackupFile] = []

  var body: some View {
    NavigationStack {
      Form {
        Section("Date Range") {
          DatePicker(
            "From",
            selection: $startDate,
            displayedComponents: .date
          )
          DatePicker(
            "Through",
            selection: $endDate,
            displayedComponents: .date
          )

          Button {
            prepareExport()
          } label: {
            Label(
              "Save JSON Export",
              systemImage: "square.and.arrow.up"
            )
          }
          .accessibilityIdentifier("saveJSONExportButton")
        }

        Section("Automatic Weekly Backups") {
          if weeklyBackups.isEmpty {
            Text(
              """
              A full-history snapshot will be saved after the \
              app is active, then at most once every seven days.
              """
            )
            .foregroundStyle(.secondary)
          } else {
            Text(
              """
              These immutable snapshots are stored separately \
              from the SwiftData database.
              """
            )
            .foregroundStyle(.secondary)

            ForEach(weeklyBackups.prefix(12)) { backup in
              ShareLink(item: backup.url) {
                Label(
                  backup.createdAt.formatted(
                    date: .abbreviated,
                    time: .shortened
                  ),
                  systemImage: "doc.badge.clock"
                )
              }
            }
          }
        }
      }
      .navigationTitle("Export Habit Data")
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
    .onAppear {
      loadInitialRange()
      refreshWeeklyBackups()
    }
    .onChange(of: startDate) {
      if startDate > endDate {
        endDate = startDate
      }
    }
    .onChange(of: endDate) {
      if endDate < startDate {
        startDate = endDate
      }
    }
    .fileExporter(
      isPresented: $isExporting,
      document: exportDocument,
      contentType: .json,
      defaultFilename: exportFilename
    ) { result in
      if case .failure(let error) = result {
        exportError = error.localizedDescription
      }
    }
    .alert(
      "Could Not Export Data",
      isPresented: Binding(
        get: { exportError != nil },
        set: { if !$0 { exportError = nil } }
      )
    ) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(exportError ?? "")
    }
    #if os(macOS)
    .frame(minWidth: 460, minHeight: 420)
    #endif
  }

  private func loadInitialRange() {
    guard !didLoadInitialRange else {
      return
    }
    didLoadInitialRange = true

    let keys = days.map(\.dateKey)
      + completions.map(\.dateKey)
    guard let firstKey = keys.min(),
      let lastKey = keys.max(),
      let firstDate = DayBoundary.displayDate(
        for: firstKey
      ),
      let lastDate = DayBoundary.displayDate(
        for: lastKey
      )
    else {
      return
    }

    startDate = firstDate
    endDate = lastDate
  }

  private func prepareExport() {
    let export = HabitDataExport.make(
      goals: goals,
      days: days,
      completions: completions,
      startDateKey: DayBoundary.calendarDateKey(
        for: startDate
      ),
      endDateKey: DayBoundary.calendarDateKey(
        for: endDate
      )
    )

    do {
      exportDocument = HabitDataExportDocument(
        data: try export.encodedJSON()
      )
      exportFilename = export.suggestedFilename
      isExporting = true
    } catch {
      exportError = error.localizedDescription
    }
  }

  private func refreshWeeklyBackups() {
    weeklyBackups =
      (try? HabitBackupStore.backups()) ?? []
  }
}
