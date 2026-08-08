import Foundation

/// Configuration for the experimental @pierre/diffs editor.
public struct PierreDiffEditorOptions: Codable, Sendable, Equatable {
  public var historyMaxEntries: Int
  public var roundedSelection: Bool
  public var matchBrackets: Bool
  public var autoSurround: PierreDiffEditorAutoSurround
  public var keymap: [String: PierreDiffEditorCommand]
  public var selectionActions: [PierreDiffSelectionAction]

  public init(
    historyMaxEntries: Int = 100,
    roundedSelection: Bool = true,
    matchBrackets: Bool = true,
    autoSurround: PierreDiffEditorAutoSurround = .default,
    keymap: [String: PierreDiffEditorCommand] = [:],
    selectionActions: [PierreDiffSelectionAction] = []
  ) {
    self.historyMaxEntries = historyMaxEntries
    self.roundedSelection = roundedSelection
    self.matchBrackets = matchBrackets
    self.autoSurround = autoSurround
    self.keymap = keymap
    self.selectionActions = selectionActions
  }
}
