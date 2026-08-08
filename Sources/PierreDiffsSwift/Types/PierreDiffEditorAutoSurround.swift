import Foundation

/// Controls which typed delimiters surround a non-empty editor selection.
public enum PierreDiffEditorAutoSurround: String, Codable, Sendable, CaseIterable {
  case `default`
  case never
  case brackets
  case quotes
  case languageDefined
}
