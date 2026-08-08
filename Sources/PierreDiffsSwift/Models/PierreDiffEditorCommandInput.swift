struct PierreDiffEditorCommandInput: Encodable {
  let type: String
  var lineNumber: Int?
  var character: Int?
  var edits: [PierreDiffTextEdit]?
  var selections: [PierreDiffEditorSelection]?
  var markers: [PierreDiffMarker]?

  init(
    type: String,
    lineNumber: Int? = nil,
    character: Int? = nil,
    edits: [PierreDiffTextEdit]? = nil,
    selections: [PierreDiffEditorSelection]? = nil,
    markers: [PierreDiffMarker]? = nil
  ) {
    self.type = type
    self.lineNumber = lineNumber
    self.character = character
    self.edits = edits
    self.selections = selections
    self.markers = markers
  }
}
