import SwiftUI

struct DateHeaderView: View {
  let dateKey: String
  let isSelected: Bool
  let onTap: () -> Void
  let onDelete: () -> Void

  var body: some View {
    let parts = DayBoundary.displayString(for: dateKey)
      .split(separator: "\n")
    let dayOfWeek = parts.first.map(String.init) ?? ""
    let monthDay = parts.count > 1
      ? String(parts[1])
      : ""

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
    .onTapGesture { onTap() }
    .contextMenu {
      Button(role: .destructive) {
        onDelete()
      } label: {
        Label("Delete Date", systemImage: "trash")
      }
    }
  }
}
