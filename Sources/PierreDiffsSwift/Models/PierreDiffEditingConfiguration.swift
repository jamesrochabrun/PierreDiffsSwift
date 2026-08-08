struct PierreDiffEditingConfiguration: Encodable {
  let enabled: Bool
  let options: PierreDiffEditorOptions
  let markers: [PierreDiffMarker]
}
