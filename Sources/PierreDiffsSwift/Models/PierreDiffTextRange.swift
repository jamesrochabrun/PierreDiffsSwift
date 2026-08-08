import Foundation

/// A zero-based, end-exclusive range in the editable new-file document.
public struct PierreDiffTextRange: Codable, Sendable, Equatable {
  public var start: PierreDiffTextPosition
  public var end: PierreDiffTextPosition

  public init(start: PierreDiffTextPosition, end: PierreDiffTextPosition) {
    self.start = start
    self.end = end
  }
}
