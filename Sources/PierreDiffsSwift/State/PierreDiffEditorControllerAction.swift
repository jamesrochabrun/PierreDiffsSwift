enum PierreDiffEditorControllerAction {
  case undo
  case redo
  case focus(lineNumber: Int?, character: Int)
  case blur
  case applyEdits([PierreDiffTextEdit])
  case setSelections([PierreDiffEditorSelection])
  case setMarkers([PierreDiffMarker])
}
