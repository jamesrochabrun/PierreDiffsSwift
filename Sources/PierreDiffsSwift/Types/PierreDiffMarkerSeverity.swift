import Foundation

/// Visual severity used by an editor marker underline and popover.
public enum PierreDiffMarkerSeverity: String, Codable, Sendable, CaseIterable {
  case error
  case warning
  case info
  case hint
}
