//
//  DiffWebViewCoordinator.swift
//  PierreDiffsSwift
//
//  Created by James Rochabrun on 1/6/26.
//

import Foundation
import WebKit

/// Coordinator that handles WKWebView delegate methods and JavaScript communication.
@MainActor
public final class DiffWebViewCoordinator: NSObject {

  // MARK: - Properties

  /// Reference to the web view (weak to avoid retain cycles)
  weak var webView: WKWebView?

  /// Callback when a line is clicked
  var onLineClick: ((Int, String) -> Void)?

  /// Callback when a line is clicked, with position data for UI overlay positioning
  var onLineClickWithPosition: ((LineClickPosition, CGPoint) -> Void)?

  /// Callback when a range of lines is selected via drag
  var onLineSelectionChange: ((LineSelectionRange) -> Void)?

  /// Callback when expand is requested
  var onExpandRequest: (() -> Void)?

  /// Callback when the WebView is ready to display content
  var onReady: (() -> Void)?

  /// Callback when an annotation is clicked (id, side, lineNumber, localPoint)
  var onAnnotationClick: ((String, String, Int, CGPoint) -> Void)?

  /// Callback when an annotation delete is requested (id, side, lineNumber)
  var onAnnotationDelete: ((String, String, Int) -> Void)?

  /// Callback when the editable new-file document changes.
  var onEditChange: ((PierreDiffEditChange) -> Void)?

  /// Callback when the editor gains focus.
  var onEditFocus: (() -> Void)?

  /// Callback when the editor loses focus.
  var onEditBlur: (() -> Void)?

  /// Callback for a configured selection action.
  var onSelectionAction: ((PierreDiffSelectionActionEvent) -> Void)?

  /// Callback for errors reported by the experimental editor.
  var onEditError: ((String) -> Void)?

  /// Optional reactive handle for imperative editor commands.
  weak var editorController: PierreDiffEditorController?

  /// Whether the web view has finished loading and is ready
  private(set) var isReady = false

  /// Queue of operations to execute once ready
  private var pendingOperations: [() -> Void] = []

  /// Whether the optional edit bundle has been evaluated in this WebView.
  private var isEditorBundleLoaded = false

  /// Whether the optional edit bundle is currently being evaluated.
  private var isEditorBundleLoading = false

  /// Operations waiting for the optional edit bundle.
  private var pendingEditorOperations: [() -> Void] = []

  // MARK: - State Tracking (for updateNSView optimization)

  var lastOldContent: String?
  var lastNewContent: String?
  var lastFileName: String?
  var lastDiffStyle: DiffStyle?
  var lastOverflowMode: OverflowMode?
  var lastTheme: String?
  var lastRenderOptions: PierreDiffRenderOptions?
  var lastAnnotations: [DiffAnnotation]?
  var lastIsEditing: Bool?
  var lastEditorOptions: PierreDiffEditorOptions?
  var lastMarkers: [PierreDiffMarker]?
  var lastEditedContent: String?
  var lastEditedAnnotations: [DiffAnnotation]?

  // MARK: - Initialization

  init(
    onLineClick: ((Int, String) -> Void)? = nil,
    onLineClickWithPosition: ((LineClickPosition, CGPoint) -> Void)? = nil,
    onLineSelectionChange: ((LineSelectionRange) -> Void)? = nil,
    onExpandRequest: (() -> Void)? = nil,
    onReady: (() -> Void)? = nil,
    onAnnotationClick: ((String, String, Int, CGPoint) -> Void)? = nil,
    onAnnotationDelete: ((String, String, Int) -> Void)? = nil,
    onEditChange: ((PierreDiffEditChange) -> Void)? = nil,
    onEditFocus: (() -> Void)? = nil,
    onEditBlur: (() -> Void)? = nil,
    onSelectionAction: ((PierreDiffSelectionActionEvent) -> Void)? = nil,
    onEditError: ((String) -> Void)? = nil,
    editorController: PierreDiffEditorController? = nil
  ) {
    self.onLineClick = onLineClick
    self.onLineClickWithPosition = onLineClickWithPosition
    self.onLineSelectionChange = onLineSelectionChange
    self.onExpandRequest = onExpandRequest
    self.onReady = onReady
    self.onAnnotationClick = onAnnotationClick
    self.onAnnotationDelete = onAnnotationDelete
    self.onEditChange = onEditChange
    self.onEditFocus = onEditFocus
    self.onEditBlur = onEditBlur
    self.onSelectionAction = onSelectionAction
    self.onEditError = onEditError
    self.editorController = editorController
    super.init()
    connectEditorController()
  }

  // MARK: - Coordinate Conversion

  /// Converts a Y position from WebView coordinates to window coordinates
  func convertToWindowCoordinates(webViewY: CGFloat) -> CGPoint? {
    guard let webView = webView,
          webView.window != nil else { return nil }

    // Convert from WebView local coordinates to window coordinates
    let pointInWebView = CGPoint(x: webView.bounds.midX, y: webViewY)
    let pointInWindow = webView.convert(pointInWebView, to: nil)

    return pointInWindow
  }

  // MARK: - Public Methods

  /// Renders a diff with the given content
  func renderDiff(
    oldContent: String,
    newContent: String,
    fileName: String,
    theme: String,
    diffStyle: DiffStyle,
    overflowMode: OverflowMode = .scroll,
    renderOptions: PierreDiffRenderOptions = PierreDiffRenderOptions(),
    annotations: [DiffAnnotation]? = nil
  ) {
    let input = PierreDiffInput(
      oldFile: PierreDiffInput.FileContents(
        name: fileName,
        contents: oldContent,
        lang: nil
      ),
      newFile: PierreDiffInput.FileContents(
        name: fileName,
        contents: newContent,
        lang: nil
      ),
      options: PierreDiffInput.Options(
        theme: PierreDiffInput.ThemeConfig(renderOptions.theme),
        themeType: theme,
        diffStyle: diffStyle.rawValue,
        overflow: overflowMode.rawValue,
        enableLineSelection: true,
        renderOptions: renderOptions
      ),
      lineAnnotations: annotations
    )

    executeWhenReady { [weak self] in
      self?.callJavaScript("renderDiff", with: input)
    }

    // Also set the theme
    setTheme(theme)
  }

  /// Sets the current theme
  func setTheme(_ theme: String) {
    executeWhenReady { [weak self] in
      self?.evaluateJavaScript("window.pierreBridge.setTheme('\(theme)')")
    }
  }

  /// Sets the diff style
  func setDiffStyle(_ style: DiffStyle) {
    executeWhenReady { [weak self] in
      self?.evaluateJavaScript("window.pierreBridge.setDiffStyle('\(style.rawValue)')")
    }
  }

  /// Sets the overflow mode (scroll or wrap)
  func setOverflow(_ mode: OverflowMode) {
    executeWhenReady { [weak self] in
      self?.evaluateJavaScript("window.pierreBridge.setOverflow('\(mode.rawValue)')")
    }
  }

  /// Sets line annotations dynamically
  func setAnnotations(_ annotations: [DiffAnnotation]) {
    executeWhenReady { [weak self] in
      self?.callJavaScript("setAnnotations", with: annotations)
    }
  }

  /// Removes all line annotations
  func removeAnnotations() {
    executeWhenReady { [weak self] in
      self?.evaluateJavaScript("window.pierreBridge.removeAnnotations()")
    }
  }

  /// Enables or disables edit mode, loading the editor bundle on first use.
  func setEditing(
    _ isEditing: Bool,
    options: PierreDiffEditorOptions,
    markers: [PierreDiffMarker]
  ) {
    let configuration = PierreDiffEditingConfiguration(
      enabled: isEditing,
      options: options,
      markers: markers
    )

    guard isEditing else {
      executeWhenReady { [weak self] in
        self?.callJavaScript("setEditing", with: configuration)
      }
      return
    }

    guard #available(macOS 14.5, *) else {
      reportEditorError("Edit mode requires macOS 14.5 or later.")
      return
    }

    executeWhenEditorReady { [weak self] in
      self?.callJavaScript("setEditing", with: configuration)
    }
  }

  /// Updates editor options without re-rendering the diff.
  func setEditorOptions(_ options: PierreDiffEditorOptions) {
    executeWhenReady { [weak self] in
      self?.callJavaScript("setEditorOptions", with: options)
    }
  }

  /// Replaces all markers without re-rendering the diff.
  func setMarkers(_ markers: [PierreDiffMarker]) {
    executeWhenReady { [weak self] in
      self?.callJavaScript("setMarkers", with: markers)
    }
  }

  func setEditorController(_ controller: PierreDiffEditorController?) {
    guard editorController !== controller else { return }
    editorController?.disconnect()
    editorController = controller
    connectEditorController()
  }

  /// Scrolls to a specific line
  func scrollToLine(_ line: Int) {
    executeWhenReady { [weak self] in
      self?.evaluateJavaScript("window.pierreBridge.scrollToLine(\(line))")
    }
  }

  /// Cleans up the diff instance and releases WebKit resources
  func cleanup() {
    webView?.stopLoading()
    webView?.navigationDelegate = nil
    webView?.configuration.userContentController.removeAllScriptMessageHandlers()
    webView?.removeFromSuperview()
    webView = nil
    onLineClick = nil
    onLineClickWithPosition = nil
    onLineSelectionChange = nil
    onExpandRequest = nil
    onReady = nil
    onAnnotationClick = nil
    onAnnotationDelete = nil
    onEditChange = nil
    onEditFocus = nil
    onEditBlur = nil
    onSelectionAction = nil
    onEditError = nil
    editorController?.disconnect()
    editorController = nil
    pendingEditorOperations.removeAll()
  }

  // MARK: - Private Methods

  private func executeWhenReady(_ operation: @escaping () -> Void) {
    if isReady {
      operation()
    } else {
      pendingOperations.append(operation)
    }
  }

  private func executePendingOperations() {
    let operations = pendingOperations
    pendingOperations.removeAll()
    operations.forEach { $0() }
  }

  private func executeWhenEditorReady(_ operation: @escaping () -> Void) {
    executeWhenReady { [weak self] in
      guard let self else { return }
      if isEditorBundleLoaded {
        operation()
        return
      }

      pendingEditorOperations.append(operation)
      loadEditorBundleIfNeeded()
    }
  }

  private func loadEditorBundleIfNeeded() {
    guard !isEditorBundleLoaded, !isEditorBundleLoading else { return }
    guard let editorJavaScript = DiffHTMLTemplate.loadBundledEditorJavaScript() else {
      reportEditorError("The bundled @pierre/diffs editor could not be loaded.")
      pendingEditorOperations.removeAll()
      return
    }
    guard let webView else {
      reportEditorError("The diff WebView is unavailable.")
      pendingEditorOperations.removeAll()
      return
    }

    isEditorBundleLoading = true
    webView.evaluateJavaScript(editorJavaScript) { [weak self] _, error in
      guard let self else { return }
      isEditorBundleLoading = false
      if let error {
        reportEditorError("Failed to load the @pierre/diffs editor: \(error.localizedDescription)")
        pendingEditorOperations.removeAll()
        return
      }

      isEditorBundleLoaded = true
      let operations = pendingEditorOperations
      pendingEditorOperations.removeAll()
      operations.forEach { $0() }
    }
  }

  private func connectEditorController() {
    editorController?.connect { [weak self] action in
      self?.performEditorControllerAction(action)
    }
  }

  private func performEditorControllerAction(_ action: PierreDiffEditorControllerAction) {
    let input: PierreDiffEditorCommandInput
    switch action {
    case .undo:
      input = PierreDiffEditorCommandInput(type: "undo")
    case .redo:
      input = PierreDiffEditorCommandInput(type: "redo")
    case .focus(let lineNumber, let character):
      input = PierreDiffEditorCommandInput(
        type: "focus",
        lineNumber: lineNumber,
        character: character
      )
    case .blur:
      input = PierreDiffEditorCommandInput(type: "blur")
    case .applyEdits(let edits):
      input = PierreDiffEditorCommandInput(type: "applyEdits", edits: edits)
    case .setSelections(let selections):
      input = PierreDiffEditorCommandInput(
        type: "setSelections",
        selections: selections
      )
    case .setMarkers(let markers):
      input = PierreDiffEditorCommandInput(type: "setMarkers", markers: markers)
    }

    executeWhenReady { [weak self] in
      self?.callJavaScript("editorCommand", with: input)
    }
  }

  private func reportEditorError(_ message: String) {
    DiffLogger.error("DiffWebViewCoordinator: \(message)")
    onEditError?(message)
  }

  private func callJavaScript<T: Encodable>(_ method: String, with input: T) {
    do {
      let encoder = JSONEncoder()
      let jsonData = try encoder.encode(input)

      // Use base64 encoding to safely transfer data with special characters
      let base64String = jsonData.base64EncodedString()

      evaluateJavaScript(Self.bridgeScript(method: method, base64Payload: base64String))
    } catch {
      DiffLogger.error("DiffWebViewCoordinator: Failed to encode input: \(error)")
    }
  }

  /// The JavaScript trampoline that hands a base64-encoded JSON payload to the
  /// page's bridge object.
  ///
  /// `atob` yields one JavaScript character per *byte*, so parsing its result
  /// directly reads the UTF-8 bytes JSONEncoder produced as Latin-1, and every
  /// non-ASCII scalar surfaces as mojibake: an en dash arrives as two stray
  /// characters, accented file contents are garbled, emoji are destroyed.
  /// Feeding the bytes through `TextDecoder` keeps the payload UTF-8 clean.
  static func bridgeScript(method: String, base64Payload: String) -> String {
    """
    (function() {
      try {
        const binary = atob('\(base64Payload)');
        const bytes = Uint8Array.from(binary, (character) => character.charCodeAt(0));
        const input = JSON.parse(new TextDecoder('utf-8').decode(bytes));
        window.pierreBridge.\(method)(input);
      } catch (e) {
        console.error('Failed to decode/parse input:', e);
        if (window.webkit?.messageHandlers?.diffBridge) {
          window.webkit.messageHandlers.diffBridge.postMessage({ type: 'error', message: e.message });
        }
      }
    })();
    """
  }

  private func evaluateJavaScript(_ script: String) {
    webView?.evaluateJavaScript(script) { _, error in
      if let error {
        DiffLogger.error("DiffWebViewCoordinator: JavaScript error: \(error)")
      }
    }
  }

  private func handleMessage(_ message: DiffWebViewEvent) {
    switch message {
    case .bridgeReady, .ready:
      isReady = true
      executePendingOperations()
      onReady?()

    case .lineClicked(let lineNumber, let side, _, _):
      // Always call the simple callback
      onLineClick?(lineNumber, side)

      // Also call the position callback if set, using NSEvent.mouseLocation for reliable positioning
      if let onLineClickWithPosition = onLineClickWithPosition {
        // Use macOS mouse location - more reliable than JavaScript coordinates
        let screenPoint = NSEvent.mouseLocation

        // Convert screen coordinates to WebView local coordinates
        if let webView = webView, let window = webView.window {
          // Get WebView's frame in window coordinates
          let webViewFrameInWindow = webView.convert(webView.bounds, to: nil)

          // Convert from screen to window coordinates
          let windowPoint = window.convertPoint(fromScreen: screenPoint)

          // Calculate position relative to WebView's top-left in window coords
          // Window coords have origin at bottom-left, so WebView's top edge is at maxY
          let relativeX = windowPoint.x - webViewFrameInWindow.minX
          let relativeY = webViewFrameInWindow.maxY - windowPoint.y  // Flip Y for top-left origin

          let position = LineClickPosition(
            lineNumber: lineNumber,
            side: side,
            lineY: relativeY,
            lineHeight: 22 // Default line height estimate
          )

          // Pass position relative to WebView with top-left origin (matches SwiftUI)
          let localPoint = CGPoint(x: relativeX, y: relativeY)
          onLineClickWithPosition(position, localPoint)
        }
      }

    case .selectionChanged(let startLine, let endLine, let side):
      DiffLogger.info("Selection changed: lines \(startLine)-\(endLine) on \(side)")
      let selection = LineSelectionRange(
        startLine: startLine,
        endLine: endLine,
        side: side
      )
      onLineSelectionChange?(selection)

    case .annotationClicked(let id, let side, let lineNumber):
      DiffLogger.info("Annotation clicked: id=\(id), side=\(side), line=\(lineNumber)")
      if let onAnnotationClick {
        let screenPoint = NSEvent.mouseLocation
        if let webView, let window = webView.window {
          let webViewFrameInWindow = webView.convert(webView.bounds, to: nil)
          let windowPoint = window.convertPoint(fromScreen: screenPoint)
          let relativeX = windowPoint.x - webViewFrameInWindow.minX
          let relativeY = webViewFrameInWindow.maxY - windowPoint.y
          onAnnotationClick(id, side, lineNumber, CGPoint(x: relativeX, y: relativeY))
        }
      }

    case .annotationDeleteRequested(let id, let side, let lineNumber):
      DiffLogger.info("Annotation delete requested: id=\(id), side=\(side), line=\(lineNumber)")
      onAnnotationDelete?(id, side, lineNumber)

    case .editorChanged(let change):
      lastEditedContent = change.content
      lastEditedAnnotations = change.annotations
      editorController?.update(
        content: change.content,
        isAttached: true,
        canUndo: change.canUndo,
        canRedo: change.canRedo
      )
      onEditChange?(change)

    case .editorStateChanged(let content, let isAttached, let isFocused, let canUndo, let canRedo):
      editorController?.update(
        content: content,
        isAttached: isAttached,
        isFocused: isFocused,
        canUndo: canUndo,
        canRedo: canRedo
      )

    case .editorFocused:
      editorController?.update(isFocused: true)
      onEditFocus?()

    case .editorBlurred:
      editorController?.update(isFocused: false)
      onEditBlur?()

    case .editorSelectionAction(let event):
      onSelectionAction?(event)

    case .editorError(let errorMessage):
      reportEditorError(errorMessage)

    case .systemThemeChanged(let isDark):
      DiffLogger.info("System theme changed: isDark=\(isDark)")

    case .error(let errorMessage):
      DiffLogger.error("DiffWebViewCoordinator: JS error: \(errorMessage)")
    }
  }

  private func decodeMessage<T: Decodable>(
    _ type: T.Type,
    from body: [String: Any]
  ) -> T? {
    do {
      let data = try JSONSerialization.data(withJSONObject: body)
      return try JSONDecoder().decode(type, from: data)
    } catch {
      DiffLogger.error("DiffWebViewCoordinator: Failed to decode \(type): \(error)")
      return nil
    }
  }
}

// MARK: - WKNavigationDelegate

extension DiffWebViewCoordinator: WKNavigationDelegate {

  public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    DiffLogger.info("DiffWebViewCoordinator: WebView finished loading")
  }

  public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    DiffLogger.error("DiffWebViewCoordinator: Navigation failed: \(error)")
  }

  public func webView(
    _ webView: WKWebView,
    didFailProvisionalNavigation navigation: WKNavigation!,
    withError error: Error
  ) {
    DiffLogger.error("DiffWebViewCoordinator: Provisional navigation failed: \(error)")
  }
}

// MARK: - WKScriptMessageHandler

extension DiffWebViewCoordinator: WKScriptMessageHandler {

  public func userContentController(
    _ userContentController: WKUserContentController,
    didReceive message: WKScriptMessage
  ) {
    guard message.name == "diffBridge" else { return }

    guard let body = message.body as? [String: Any],
          let typeString = body["type"] as? String else {
      DiffLogger.error("DiffWebViewCoordinator: Invalid message format")
      return
    }

    let event: DiffWebViewEvent

    switch typeString {
    case "bridgeReady":
      event = .bridgeReady

    case "ready":
      event = .ready

    case "lineClicked":
      let lineNumber = body["lineNumber"] as? Int ?? 0
      let side = body["side"] as? String ?? "unknown"
      let lineY = (body["lineY"] as? NSNumber)?.doubleValue ?? 0
      let lineHeight = (body["lineHeight"] as? NSNumber)?.doubleValue ?? 20
      event = .lineClicked(lineNumber: lineNumber, side: side, lineY: CGFloat(lineY), lineHeight: CGFloat(lineHeight))

    case "selectionChanged":
      let startLine = body["startLine"] as? Int ?? 0
      let endLine = body["endLine"] as? Int ?? 0
      let side = body["side"] as? String ?? "unknown"
      event = .selectionChanged(startLine: startLine, endLine: endLine, side: side)

    case "annotationClicked":
      let id = body["id"] as? String ?? ""
      let side = body["side"] as? String ?? ""
      let lineNumber = body["lineNumber"] as? Int ?? 0
      event = .annotationClicked(id: id, side: side, lineNumber: lineNumber)

    case "annotationDeleteRequested":
      let id = body["id"] as? String ?? ""
      let side = body["side"] as? String ?? ""
      let lineNumber = body["lineNumber"] as? Int ?? 0
      event = .annotationDeleteRequested(id: id, side: side, lineNumber: lineNumber)

    case "editorChanged":
      guard let change = decodeMessage(PierreDiffEditChange.self, from: body) else {
        return
      }
      event = .editorChanged(change)

    case "editorStateChanged":
      let content = body["content"] as? String ?? ""
      let isAttached = body["isAttached"] as? Bool ?? false
      let isFocused = body["isFocused"] as? Bool
      let canUndo = body["canUndo"] as? Bool ?? false
      let canRedo = body["canRedo"] as? Bool ?? false
      event = .editorStateChanged(
        content: content,
        isAttached: isAttached,
        isFocused: isFocused,
        canUndo: canUndo,
        canRedo: canRedo
      )

    case "editorFocused":
      event = .editorFocused

    case "editorBlurred":
      event = .editorBlurred

    case "editorSelectionAction":
      guard let selectionAction = decodeMessage(
        PierreDiffSelectionActionEvent.self,
        from: body
      ) else {
        return
      }
      event = .editorSelectionAction(selectionAction)

    case "editorError":
      event = .editorError(message: body["message"] as? String ?? "Unknown editor error")

    case "systemThemeChanged":
      let isDark = body["isDark"] as? Bool ?? false
      event = .systemThemeChanged(isDark: isDark)

    case "error":
      let errorMessage = body["message"] as? String ?? "Unknown error"
      event = .error(message: errorMessage)

    default:
      DiffLogger.info("DiffWebViewCoordinator: Unknown message type: \(typeString)")
      return
    }

    handleMessage(event)
  }
}
