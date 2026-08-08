import Observation

/// A reactive handle for editor state and imperative editor commands.
@Observable @MainActor
public final class PierreDiffEditorController {
  public private(set) var isAttached = false
  public private(set) var isFocused = false
  public private(set) var canUndo = false
  public private(set) var canRedo = false
  public private(set) var content = ""

  @ObservationIgnored
  private var actionHandler: ((PierreDiffEditorControllerAction) -> Void)?

  public init() {}

  public func undo() {
    actionHandler?(.undo)
  }

  public func redo() {
    actionHandler?(.redo)
  }

  /// Focuses the editor. `lineNumber` is one-based; `character` is zero-based.
  public func focus(lineNumber: Int? = nil, character: Int = 0) {
    actionHandler?(.focus(lineNumber: lineNumber, character: character))
  }

  public func blur() {
    actionHandler?(.blur)
  }

  public func applyEdits(_ edits: [PierreDiffTextEdit]) {
    actionHandler?(.applyEdits(edits))
  }

  public func setSelections(_ selections: [PierreDiffEditorSelection]) {
    actionHandler?(.setSelections(selections))
  }

  public func setMarkers(_ markers: [PierreDiffMarker]) {
    actionHandler?(.setMarkers(markers))
  }

  func connect(_ actionHandler: @escaping (PierreDiffEditorControllerAction) -> Void) {
    self.actionHandler = actionHandler
  }

  func update(
    content: String? = nil,
    isAttached: Bool? = nil,
    isFocused: Bool? = nil,
    canUndo: Bool? = nil,
    canRedo: Bool? = nil
  ) {
    if let content {
      self.content = content
    }
    if let isAttached {
      self.isAttached = isAttached
    }
    if let isFocused {
      self.isFocused = isFocused
    }
    if let canUndo {
      self.canUndo = canUndo
    }
    if let canRedo {
      self.canRedo = canRedo
    }
  }

  func disconnect() {
    actionHandler = nil
    isAttached = false
    isFocused = false
    canUndo = false
    canRedo = false
  }
}
