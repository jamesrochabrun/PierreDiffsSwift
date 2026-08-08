import Foundation

/// Commands supported by an @pierre/diffs editor key binding.
public enum PierreDiffEditorCommand: String, Codable, Sendable, CaseIterable {
  case indent
  case outdent
  case indentLess
  case indentMore
  case undo
  case redo
  case selectAll
  case findNextMatch
  case openSearchPanel
  case openSearchReplacePanel
  case moveLineUp
  case moveLineDown
  case copyLineUp
  case copyLineDown
  case simplifySelection
  case insertBlankLine
  case deleteHardLineForward
  case toggleComment
  case toggleBlockComment
  case moveCursorToDocStart
  case moveCursorToDocEnd
  case expandSelectionDocStart
  case expandSelectionDocEnd
}
