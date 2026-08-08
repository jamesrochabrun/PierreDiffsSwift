import Foundation

/// A controlled editor update containing the complete new-file contents.
public struct PierreDiffEditChange: Codable, Sendable, Equatable {
  public let fileName: String
  public let content: String
  public let annotations: [DiffAnnotation]?
  public let changes: [PierreDiffEditorChange]
  public let canUndo: Bool
  public let canRedo: Bool

  public init(
    fileName: String,
    content: String,
    annotations: [DiffAnnotation]?,
    changes: [PierreDiffEditorChange],
    canUndo: Bool,
    canRedo: Bool
  ) {
    self.fileName = fileName
    self.content = content
    self.annotations = annotations
    self.changes = changes
    self.canUndo = canUndo
    self.canRedo = canRedo
  }
}
