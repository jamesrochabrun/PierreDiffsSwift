import Foundation

/// A button displayed in the floating popover for a non-empty text selection.
public struct PierreDiffSelectionAction: Codable, Sendable, Equatable, Identifiable {
  public let id: String
  public var title: String

  public init(id: String, title: String) {
    self.id = id
    self.title = title
  }
}
