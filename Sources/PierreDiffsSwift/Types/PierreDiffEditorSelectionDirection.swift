import Foundation

/// Direction of an editor selection.
public enum PierreDiffEditorSelectionDirection: Int, Codable, Sendable {
  case backward = -1
  case none = 0
  case forward = 1
}
