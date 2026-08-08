import Foundation

/// The selected text and range delivered when a selection action is chosen.
public struct PierreDiffSelectionActionEvent: Codable, Sendable, Equatable {
  public let actionID: String
  public let selectedText: String
  public let selection: PierreDiffEditorSelection

  public init(
    actionID: String,
    selectedText: String,
    selection: PierreDiffEditorSelection
  ) {
    self.actionID = actionID
    self.selectedText = selectedText
    self.selection = selection
  }
}
