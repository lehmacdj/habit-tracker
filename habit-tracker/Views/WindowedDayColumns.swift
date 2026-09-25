import SwiftUI

/// Spacers preserve the scroll extent while offscreen cells are retired.
/// Date IDs keep the remaining cells stable as the window moves.
struct WindowedDayColumns<Content: View>: View {
  let keys: [String]
  let range: Range<Int>
  @ViewBuilder let content: (String) -> Content

  var body: some View {
    HStack(spacing: 0) {
      Color.clear
        .frame(width: CGFloat(range.lowerBound) * GridViewport.cellWidth)
        .accessibilityHidden(true)
      ForEach(Array(keys[range]), id: \.self, content: content)
      Color.clear
        .frame(width: CGFloat(keys.count - range.upperBound)
          * GridViewport.cellWidth)
        .accessibilityHidden(true)
    }
    .frame(height: GridViewport.cellWidth)
  }
}
