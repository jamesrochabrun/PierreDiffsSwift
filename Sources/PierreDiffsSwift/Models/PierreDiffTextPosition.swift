import Foundation

/// A zero-based position in the editable new-file document.
public struct PierreDiffTextPosition: Codable, Sendable, Equatable {
  public var line: Int
  public var character: Int

  public init(line: Int, character: Int) {
    self.line = line
    self.character = character
  }
}
