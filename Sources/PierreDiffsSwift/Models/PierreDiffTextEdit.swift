import Foundation

/// A programmatic replacement applied to the editor and its undo history.
public struct PierreDiffTextEdit: Codable, Sendable, Equatable {
  public var range: PierreDiffTextRange
  public var newText: String

  public init(range: PierreDiffTextRange, newText: String) {
    self.range = range
    self.newText = newText
  }
}
