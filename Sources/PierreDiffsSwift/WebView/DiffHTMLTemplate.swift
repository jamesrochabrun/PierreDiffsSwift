//
//  DiffHTMLTemplate.swift
//  PierreDiffsSwift
//
//  Created by James Rochabrun on 1/6/26.
//

import Foundation

/// Generates the HTML template for the Pierre Diff WebView.
enum DiffHTMLTemplate {

  /// Generates the complete HTML string with embedded JavaScript and CSS.
  static func generateHTML() -> String {
    let bundleJS = loadBundledJavaScript()

    return """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            \(styles)
        </style>
    </head>
    <body>
        <div id="diff-container"></div>
        <script>
            \(bundleJS)
        </script>
    </body>
    </html>
    """
  }

  // MARK: - Private

  /// Loads the bundled JavaScript from the app resources.
  private static func loadBundledJavaScript() -> String {
    // Try to load from bundle resources
    // First try with subdirectory (for .copy with directory structure)
    var bundleURL = Bundle.module.url(
      forResource: "pierre-diffs-bundle",
      withExtension: "js",
      subdirectory: "Resources"
    )

    // If not found, try without subdirectory (for flattened resources)
    if bundleURL == nil {
      bundleURL = Bundle.module.url(
        forResource: "pierre-diffs-bundle",
        withExtension: "js"
      )
    }

    guard let bundleURL else {
      DiffLogger.error("DiffHTMLTemplate: Could not find pierre-diffs-bundle.js in bundle")
      return fallbackJavaScript
    }

    do {
      let content = try String(contentsOf: bundleURL, encoding: .utf8)
      return content
    } catch {
      DiffLogger.error("DiffHTMLTemplate: Failed to load pierre-diffs-bundle.js: \(error)")
      return fallbackJavaScript
    }
  }

  /// Loads the optional editor bundle only when edit mode is requested.
  static func loadBundledEditorJavaScript() -> String? {
    var bundleURL = Bundle.module.url(
      forResource: "pierre-diffs-edit-bundle",
      withExtension: "js",
      subdirectory: "Resources"
    )

    if bundleURL == nil {
      bundleURL = Bundle.module.url(
        forResource: "pierre-diffs-edit-bundle",
        withExtension: "js"
      )
    }

    guard let bundleURL else {
      DiffLogger.error("DiffHTMLTemplate: Could not find pierre-diffs-edit-bundle.js in bundle")
      return nil
    }

    do {
      return try String(contentsOf: bundleURL, encoding: .utf8)
    } catch {
      DiffLogger.error("DiffHTMLTemplate: Failed to load pierre-diffs-edit-bundle.js: \(error)")
      return nil
    }
  }

  /// Fallback JavaScript when bundle loading fails
  private static let fallbackJavaScript = """
  window.pierreBridge = {
    renderDiff: function(input) {
      const container = document.getElementById('diff-container');
      container.innerHTML = '<div style="color: red; padding: 20px;">Failed to load diff library. Please restart the application.</div>';
      if (window.webkit?.messageHandlers?.diffBridge) {
        window.webkit.messageHandlers.diffBridge.postMessage({ type: 'error', message: 'Bundle not loaded' });
      }
    },
    setTheme: function() {},
    setDiffStyle: function() {},
    scrollToLine: function() {},
    getSelection: function() { return ''; },
    setEditing: function() {},
    setEditorOptions: function() {},
    setMarkers: function() {},
    editorCommand: function() {},
    cleanup: function() {}
  };
  """

  /// CSS styles for the diff view
  private static let styles = """
  * {
    box-sizing: border-box;
  }

  :root {
    --diffs-font-family: ui-monospace, 'SF Mono', Menlo, Monaco, 'Cascadia Code', 'Roboto Mono', monospace;
    --diffs-font-size: 12px;
    --diffs-line-height: 1.5;
    --diffs-tab-size: 2;
    --diffs-header-font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
    --diffs-min-number-column-width: 4ch;
  }

  html, body {
    margin: 0;
    padding: 0;
    height: 100%;
    width: 100%;
    overflow: hidden;
    font-family: var(--diffs-font-family);
    font-size: var(--diffs-font-size);
    line-height: var(--diffs-line-height);
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
  }

  body {
    background-color: transparent;
  }

  #diff-container {
    width: 100%;
    height: 100%;
    overflow: auto;
  }

  /* Scrollbar styling for macOS feel */
  ::-webkit-scrollbar {
    width: 8px;
    height: 8px;
  }

  ::-webkit-scrollbar-track {
    background: transparent;
  }

  ::-webkit-scrollbar-thumb {
    background-color: rgba(128, 128, 128, 0.3);
    border-radius: 4px;
  }

  ::-webkit-scrollbar-thumb:hover {
    background-color: rgba(128, 128, 128, 0.5);
  }

  /* Dark mode adjustments */
  @media (prefers-color-scheme: dark) {
    ::-webkit-scrollbar-thumb {
      background-color: rgba(255, 255, 255, 0.2);
    }

    ::-webkit-scrollbar-thumb:hover {
      background-color: rgba(255, 255, 255, 0.3);
    }
  }

  /* Selection styling */
  ::selection {
    background-color: rgba(59, 130, 246, 0.3);
  }

  .pierre-selection-actions {
    display: flex;
    gap: 4px;
    padding: 4px;
    border: 1px solid rgba(140, 140, 160, 0.25);
    border-radius: 7px;
    background: rgba(255, 255, 255, 0.96);
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.16);
    font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
  }

  .pierre-selection-actions button {
    border: 0;
    border-radius: 5px;
    padding: 5px 8px;
    background: transparent;
    color: #262626;
    font: inherit;
    cursor: pointer;
  }

  .pierre-selection-actions button:hover,
  .pierre-selection-actions button:focus-visible {
    background: rgba(120, 87, 255, 0.12);
    outline: none;
  }

  /* Hide file header if desired */
  .diffs-header {
    display: none;
  }

  /* Inline annotation styles */
  .pierre-annotation {
    margin: 6px 4px;
    padding: 10px 12px;
    border: 1px solid rgba(140, 140, 160, 0.18);
    border-left: 3px solid rgba(120, 87, 255, 0.8);
    border-radius: 8px;
    background-color: rgba(255, 255, 255, 0.9);
    font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
    font-size: 12px;
    cursor: pointer;
    transition: background-color 0.15s ease, border-color 0.15s ease, box-shadow 0.15s ease;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1), 0 1px 3px rgba(0, 0, 0, 0.06);
  }

  .pierre-annotation:hover {
    background-color: rgba(255, 255, 255, 0.95);
    border-color: rgba(140, 140, 160, 0.3);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.14), 0 2px 4px rgba(0, 0, 0, 0.08);
  }

  .pierre-annotation-row {
    display: flex;
    gap: 8px;
    align-items: flex-start;
  }

  .pierre-annotation-avatar {
    width: 22px;
    height: 22px;
    border-radius: 50%;
    flex-shrink: 0;
    overflow: hidden;
    display: flex;
    align-items: center;
    justify-content: center;
    background-color: rgba(96, 165, 250, 0.15);
    color: rgba(96, 165, 250, 0.8);
    margin-top: 1px;
  }

  .pierre-annotation-avatar img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    border-radius: 50%;
  }

  .pierre-annotation-avatar svg {
    width: 14px;
    height: 14px;
  }

  .pierre-annotation-content {
    flex: 1;
    min-width: 0;
  }

  .pierre-annotation-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 2px;
  }

  .pierre-annotation-subtitle {
    font-weight: 500;
    font-size: 11px;
    color: inherit;
    opacity: 0.5;
  }

  .pierre-annotation-delete {
    display: none;
    border: none;
    background: none;
    color: inherit;
    font-size: 16px;
    line-height: 1;
    cursor: pointer;
    padding: 2px 4px;
    border-radius: 4px;
    opacity: 0.5;
    transition: opacity 0.15s ease, background-color 0.15s ease;
  }

  .pierre-annotation:hover .pierre-annotation-delete {
    display: inline-flex;
  }

  .pierre-annotation-delete:hover {
    opacity: 1;
    background-color: rgba(239, 68, 68, 0.15);
    color: rgba(239, 68, 68, 0.9);
  }

  .pierre-annotation-body {
    color: inherit;
    opacity: 0.85;
    font-size: 12px;
    line-height: 1.5;
    white-space: pre-wrap;
    word-break: break-word;
  }

  @media (prefers-color-scheme: dark) {
    .pierre-selection-actions {
      border-color: rgba(160, 160, 180, 0.28);
      background: rgba(31, 31, 35, 0.97);
      box-shadow: 0 4px 16px rgba(0, 0, 0, 0.35);
    }

    .pierre-selection-actions button {
      color: #f0f0f0;
    }

    .pierre-annotation {
      border-color: rgba(200, 200, 220, 0.1);
      border-left-color: rgba(120, 87, 255, 0.7);
      background-color: rgba(30, 32, 38, 0.9);
      box-shadow: 0 2px 10px rgba(0, 0, 0, 0.3), 0 1px 4px rgba(0, 0, 0, 0.2);
    }

    .pierre-annotation:hover {
      background-color: rgba(36, 38, 46, 0.95);
      border-color: rgba(200, 200, 220, 0.18);
      box-shadow: 0 4px 14px rgba(0, 0, 0, 0.35), 0 2px 6px rgba(0, 0, 0, 0.25);
    }

    .pierre-annotation-avatar {
      background-color: rgba(96, 165, 250, 0.12);
      color: rgba(96, 165, 250, 0.7);
    }
  }
  """
}
