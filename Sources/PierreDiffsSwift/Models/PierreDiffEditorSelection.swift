import Foundation

/// A text selection that can be installed in the editor programmatically.
public struct PierreDiffEditorSelection: Codable, Sendable, Equatable {
  public var start: PierreDiffTextPosition
  public var end: PierreDiffTextPosition
  public var direction: PierreDiffEditorSelectionDirection

  public init(
    start: PierreDiffTextPosition,
    end: PierreDiffTextPosition,
    direction: PierreDiffEditorSelectionDirection = .none
  ) {
    self.start = start
    self.end = end
    self.direction = direction
  }
}
