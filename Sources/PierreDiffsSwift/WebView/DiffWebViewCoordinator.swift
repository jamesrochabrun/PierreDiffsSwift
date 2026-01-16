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

  /// Callback when expand is requested
  var onExpandRequest: (() -> Void)?

  /// Callback when the WebView is ready to display content
  var onReady: (() -> Void)?

  /// Whether the web view has finished loading and is ready
  private(set) var isReady = false

  /// Queue of operations to execute once ready
  private var pendingOperations: [() -> Void] = []

  // MARK: - State Tracking (for updateNSView optimization)

  var lastOldContent: String?
  var lastNewContent: String?
  var lastFileName: String?
  var lastDiffStyle: DiffStyle?
  var lastOverflowMode: OverflowMode?
  var lastTheme: String?

  // MARK: - Initialization

  init(
    onLineClick: ((Int, String) -> Void)? = nil,
    onLineClickWithPosition: ((LineClickPosition, CGPoint) -> Void)? = nil,
    onExpandRequest: (() -> Void)? = nil,
    onReady: (() -> Void)? = nil
  ) {
    self.onLineClick = onLineClick
    self.onLineClickWithPosition = onLineClickWithPosition
    self.onExpandRequest = onExpandRequest
    self.onReady = onReady
    super.init()
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
    overflowMode: OverflowMode = .scroll
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
        theme: PierreDiffInput.ThemeConfig(
          dark: "pierre-dark",
          light: "pierre-light"
        ),
        diffStyle: diffStyle.rawValue,
        overflow: overflowMode.rawValue,
        enableLineSelection: true
      )
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

  /// Scrolls to a specific line
  func scrollToLine(_ line: Int) {
    executeWhenReady { [weak self] in
      self?.evaluateJavaScript("window.pierreBridge.scrollToLine(\(line))")
    }
  }

  /// Cleans up the diff instance
  func cleanup() {
    evaluateJavaScript("window.pierreBridge.cleanup()")
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

  private func callJavaScript<T: Encodable>(_ method: String, with input: T) {
    do {
      let encoder = JSONEncoder()
      let jsonData = try encoder.encode(input)

      // Use base64 encoding to safely transfer data with special characters
      let base64String = jsonData.base64EncodedString()

      // JavaScript will decode base64 and parse JSON
      let script = """
      (function() {
        try {
          const decoded = atob('\(base64String)');
          const input = JSON.parse(decoded);
          window.pierreBridge.\(method)(input);
        } catch (e) {
          console.error('Failed to decode/parse input:', e);
          if (window.webkit?.messageHandlers?.diffBridge) {
            window.webkit.messageHandlers.diffBridge.postMessage({ type: 'error', message: e.message });
          }
        }
      })();
      """
      evaluateJavaScript(script)
    } catch {
      DiffLogger.error("DiffWebViewCoordinator: Failed to encode input: \(error)")
    }
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

    case .systemThemeChanged(let isDark):
      DiffLogger.info("System theme changed: isDark=\(isDark)")

    case .error(let errorMessage):
      DiffLogger.error("DiffWebViewCoordinator: JS error: \(errorMessage)")
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
