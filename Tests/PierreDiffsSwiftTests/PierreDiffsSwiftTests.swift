import Foundation
import Testing
@testable import PierreDiffsSwift

@Test func defaultRenderOptionsPreserveBridgeDefaults() {
  let options = PierreDiffInput.Options(
    theme: .init(dark: "pierre-dark", light: "pierre-light"),
    diffStyle: "split",
    overflow: "scroll",
    enableLineSelection: true
  )

  #expect(options.theme.dark == "pierre-dark")
  #expect(options.theme.light == "pierre-light")
  #expect(options.diffIndicators == "bars")
  #expect(options.hunkSeparators == "line-info")
  #expect(options.lineDiffType == "word-alt")
  #expect(options.disableLineNumbers == false)
  #expect(options.disableFileHeader == false)
  #expect(options.disableBackground == false)
  #expect(options.expandUnchanged == false)
  #expect(options.stickyHeader == false)
  #expect(options.collapsedContextThreshold == nil)
  #expect(options.maxLineDiffLength == nil)
  #expect(options.expansionLineCount == nil)
  #expect(options.tokenizeMaxLength == nil)
  #expect(options.tokenizeMaxLineLength == nil)
}

@Test func renderOptionsEncodeForJavaScriptBridge() throws {
  let renderOptions = PierreDiffRenderOptions(
    theme: .pierreSoft,
    diffIndicators: .classic,
    hunkSeparators: .metadata,
    lineDiffType: .char,
    disableLineNumbers: true,
    disableFileHeader: true,
    disableBackground: true,
    expandUnchanged: true,
    collapsedContextThreshold: 24,
    maxLineDiffLength: 4_096,
    expansionLineCount: 12,
    tokenizeMaxLength: 120_000,
    tokenizeMaxLineLength: 2_000,
    stickyHeader: true
  )
  let diffResult = DiffResult(
    filePath: "Sources/Example.swift",
    fileName: "Example.swift",
    original: "let value = 1\n",
    updated: "let value = 2\n"
  )

  let input = PierreDiffInput.from(
    diffResult: diffResult,
    diffStyle: .unified,
    overflowMode: .wrap,
    renderOptions: renderOptions
  )
  let data = try JSONEncoder().encode(input)
  let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  let options = try #require(object["options"] as? [String: Any])
  let theme = try #require(options["theme"] as? [String: Any])

  #expect(theme["dark"] as? String == "pierre-dark-soft")
  #expect(theme["light"] as? String == "pierre-light-soft")
  #expect(options["diffStyle"] as? String == "unified")
  #expect(options["overflow"] as? String == "wrap")
  #expect(options["diffIndicators"] as? String == "classic")
  #expect(options["hunkSeparators"] as? String == "metadata")
  #expect(options["lineDiffType"] as? String == "char")
  #expect(options["disableLineNumbers"] as? Bool == true)
  #expect(options["disableFileHeader"] as? Bool == true)
  #expect(options["disableBackground"] as? Bool == true)
  #expect(options["expandUnchanged"] as? Bool == true)
  #expect(options["collapsedContextThreshold"] as? Int == 24)
  #expect(options["maxLineDiffLength"] as? Int == 4_096)
  #expect(options["expansionLineCount"] as? Int == 12)
  #expect(options["tokenizeMaxLength"] as? Int == 120_000)
  #expect(options["tokenizeMaxLineLength"] as? Int == 2_000)
  #expect(options["stickyHeader"] as? Bool == true)
}

@Test func annotationBridgePreservesScrollWithoutForcedRerender() throws {
  let html = DiffHTMLTemplate.generateHTML()
  let setAnnotationsRange = try #require(html.range(of: "setAnnotations"))
  let removeAnnotationsRange = try #require(
    html[setAnnotationsRange.upperBound...].range(of: "removeAnnotations")
  )
  let setAnnotationsBlock = html[setAnnotationsRange.lowerBound..<removeAnnotationsRange.lowerBound]

  #expect(html.contains("scrollTop"))
  #expect(html.contains("scrollLeft"))
  #expect(setAnnotationsBlock.contains("preventEmit"))
  #expect(setAnnotationsBlock.contains(".render(") || setAnnotationsBlock.contains(".render({"))
  #expect(!setAnnotationsBlock.contains(".rerender()"))
}

@Test func editorOptionsEncodeForLazyBridge() throws {
  let options = PierreDiffEditorOptions(
    historyMaxEntries: 42,
    roundedSelection: false,
    matchBrackets: false,
    autoSurround: .quotes,
    keymap: ["cmd+Enter": .insertBlankLine],
    selectionActions: [
      PierreDiffSelectionAction(id: "add-to-chat", title: "Add to chat")
    ]
  )

  let data = try JSONEncoder().encode(options)
  let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
  let keymap = try #require(object["keymap"] as? [String: String])
  let actions = try #require(object["selectionActions"] as? [[String: Any]])

  #expect(object["historyMaxEntries"] as? Int == 42)
  #expect(object["roundedSelection"] as? Bool == false)
  #expect(object["matchBrackets"] as? Bool == false)
  #expect(object["autoSurround"] as? String == "quotes")
  #expect(keymap["cmd+Enter"] == "insertBlankLine")
  #expect(actions.first?["id"] as? String == "add-to-chat")
}

@Test func editChangeDecodesShiftedAnnotationsAndNormalizedEdits() throws {
  let json = """
  {
    "fileName": "Example.swift",
    "content": "let value = 2\\n",
    "annotations": [{
      "side": "additions",
      "lineNumber": 2,
      "metadata": {"id": "review-1", "author": "You", "body": "Check this"}
    }],
    "changes": [{
      "start": 12,
      "end": 13,
      "text": "2",
      "range": {
        "start": {"line": 0, "character": 12},
        "end": {"line": 0, "character": 13}
      }
    }],
    "canUndo": true,
    "canRedo": false
  }
  """

  let change = try JSONDecoder().decode(
    PierreDiffEditChange.self,
    from: Data(json.utf8)
  )

  #expect(change.content == "let value = 2\n")
  #expect(change.annotations?.first?.lineNumber == 2)
  #expect(change.changes.first?.range.start.character == 12)
  #expect(change.canUndo)
  #expect(!change.canRedo)
}

@Test @MainActor func editorControllerTracksPublishedState() {
  let controller = PierreDiffEditorController()

  controller.update(
    content: "updated",
    isAttached: true,
    isFocused: true,
    canUndo: true,
    canRedo: false
  )

  #expect(controller.content == "updated")
  #expect(controller.isAttached)
  #expect(controller.isFocused)
  #expect(controller.canUndo)
  #expect(!controller.canRedo)
}

@Test func editorBundleHasASeparateLazyEntryPoint() throws {
  let repository = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
  let mainEntry = try String(
    contentsOf: repository.appending(path: "scripts/src/diff-entry.js"),
    encoding: .utf8
  )
  let editEntry = try String(
    contentsOf: repository.appending(path: "scripts/src/edit-entry.js"),
    encoding: .utf8
  )

  #expect(!mainEntry.contains("from '@pierre/diffs/edit'"))
  #expect(editEntry.contains("from '@pierre/diffs/edit'"))
  #expect(mainEntry.contains("setEditing(configuration"))
  #expect(mainEntry.contains("editorCommand(command"))
}
