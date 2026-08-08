import Foundation

/// One normalized document replacement reported by @pierre/diffs.
public struct PierreDiffEditorChange: Codable, Sendable, Equatable {
  public let start: Int
  public let end: Int
  public let text: String
  public let range: PierreDiffTextRange

  public init(start: Int, end: Int, text: String, range: PierreDiffTextRange) {
    self.start = start
    self.end = end
    self.text = text
    self.range = range
  }
}
