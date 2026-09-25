import Foundation

/// Quantized content coordinates, shared by the header and every row.
/// Four-column buckets avoid publishing state on every scroll pixel.
struct GridViewport: Equatable {
  static let cellWidth: CGFloat = 48
  static let goalWidth: CGFloat = 160
  private static let bucketWidth = cellWidth * 4
  let lowerBound: CGFloat
  let upperBound: CGFloat

  init(offset: CGFloat, width: CGFloat) {
    lowerBound = floor(max(0, offset) / Self.bucketWidth)
      * Self.bucketWidth
    upperBound = ceil(max(0, offset + width) / Self.bucketWidth)
      * Self.bucketWidth
  }

  /// Prefetch four dates on either side. Clamping handles overscroll,
  /// empty sections, and the wider Goals column between them.
  func range(count: Int, origin: CGFloat) -> Range<Int> {
    let first = Int(floor((lowerBound - origin) / Self.cellWidth)) - 4
    let last = Int(ceil((upperBound - origin) / Self.cellWidth)) + 4
    let start = min(count, max(0, first))
    return start..<min(count, max(start, last))
  }
}
