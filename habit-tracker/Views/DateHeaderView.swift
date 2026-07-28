import SwiftUI

struct DateHeaderView: View {
  let dateKey: String
  let isSelected: Bool
  let canDelete: Bool
  let canInsertPrevious: Bool
  let canInsertNext: Bool
  let onTap: () -> Void
  let onDelete: () -> Void
  let onInsertPrevious: () -> Void
  let onInsertNext: () -> Void

  var body: some View {
    let parts = DayBoundary.displayString(for: dateKey)
      .split(separator: "\n")
    let dayOfWeek = parts.first.map(String.init) ?? ""
    let monthDay = parts.count > 1
      ? String(parts[1])
      : ""

    Button(action: onTap) {
      VStack(spacing: 2) {
        Text(dayOfWeek)
          .font(.caption)
          .fontWeight(isSelected ? .bold : .regular)
        Text(monthDay)
          .font(.caption2)
      }
      .frame(width: 48, height: 48)
      .background(
        isSelected
          ? Color.accentColor.opacity(0.15)
          : Color.clear
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier("dateHeader-\(dateKey)")
    .contextMenu {
      if canInsertPrevious {
        Button {
          onInsertPrevious()
        } label: {
          Label(
            "Insert Previous Day",
            systemImage: "calendar.badge.plus"
          )
        }
      }

      if canInsertNext {
        Button {
          onInsertNext()
        } label: {
          Label(
            "Insert Next Day",
            systemImage: "calendar.badge.plus"
          )
        }
      }

      if canDelete {
        Button(role: .destructive) {
          onDelete()
        } label: {
          Label("Delete Date", systemImage: "trash")
        }
      }
    }
  }
}
