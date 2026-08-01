import AppKit
import Foundation
import Testing
import WebKit
@testable import PierreDiffsSwift

/// Expanding a collapsed-context hunk re-renders the whole diff. Without an
/// anchor the scroll container is rebuilt at the top, throwing the reader back
/// to the first line of the file; expanding upward additionally inserts rows
/// above the viewport. These tests pin the reading position across both.
@MainActor
@Test func expandingHunkKeepsReadingPosition() async throws {
  let harness = try await DiffHarness.render()

  // Park the first expander above the viewport, the way a reader who scrolled
  // past a collapsed region sits.
  let before = try await harness.evaluate("""
  (function() {
    const container = document.getElementById('diff-container');
    const root = container.querySelector('diffs-container').shadowRoot;
    const button = root.querySelector('[data-expand-button]');
    window.__expander = button;
    container.scrollTop = container.scrollTop + button.getBoundingClientRect().top - 120;
    const anchor = window.__harness.anchor();
    return { scrollTop: container.scrollTop, anchorLine: anchor.line, anchorOffset: anchor.offset };
  })();
  """)

  _ = try await harness.evaluate("window.__expander.click(); true;")
  try await harness.settle()

  let after = try await harness.evaluate("""
  (function() {
    const container = document.getElementById('diff-container');
    const root = container.querySelector('diffs-container').shadowRoot;
    return { scrollTop: container.scrollTop,
             anchorOffset: window.__harness.offsetOfLine(window.__anchorLine),
             rows: root.querySelectorAll('[data-line]').length };
  })();
  """)

  let scrollTop = try #require(after["scrollTop"] as? Double)
  let offsetBefore = try #require(before["anchorOffset"] as? Double)
  let offsetAfter = try #require(after["anchorOffset"] as? Double)

  // The expansion really happened…
  #expect(try #require(after["rows"] as? Double) > 0)
  // …and the reader did not get snapped back to the top of the file.
  #expect(scrollTop > 0)
  #expect(abs(offsetAfter - offsetBefore) < 4)
}

// MARK: - Harness

@MainActor
private struct DiffHarness {
  let webView: WKWebView

  static func render() async throws -> DiffHarness {
    func file(_ marker: String) -> String {
      let head = (1...60).map { "\(marker) head \($0)" }
      let middle = (1...400).map { "shared middle \($0)" }
      let tail = (1...60).map { "\(marker) tail \($0)" }
      return (head + middle + tail).joined(separator: "\n")
    }

    let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
                          styleMask: [.titled], backing: .buffered, defer: false)
    window.contentView?.addSubview(webView)
    window.makeKeyAndOrderFront(nil)

    let loader = HarnessLoadObserver()
    try await loader.wait(for: webView, loading: DiffHTMLTemplate.generateHTML())

    let payload = try JSONEncoder().encode([
      "oldFile": ["name": "sample.txt", "contents": file("old")],
      "newFile": ["name": "sample.txt", "contents": file("new")],
    ]).base64EncodedString()

    let harness = DiffHarness(webView: webView)
    _ = try await harness.evaluate("""
    (function() {
      const bytes = Uint8Array.from(atob('\(payload)'), (c) => c.charCodeAt(0));
      const input = JSON.parse(new TextDecoder('utf-8').decode(bytes));
      window.pierreBridge.renderDiff({
        oldFile: input.oldFile,
        newFile: input.newFile,
        options: { theme: { dark: 'pierre-dark', light: 'pierre-light' }, themeType: 'dark',
                   diffStyle: 'split', overflow: 'scroll', enableLineSelection: true },
      });
      window.__harness = {
        root() { return document.getElementById('diff-container').querySelector('diffs-container').shadowRoot; },
        containerTop() { return document.getElementById('diff-container').getBoundingClientRect().top; },
        anchor() {
          const top = this.containerTop();
          for (const row of this.root().querySelectorAll('[data-line]')) {
            const rect = row.getBoundingClientRect();
            if (rect.bottom <= top) continue;
            window.__anchorLine = row.getAttribute('data-line');
            return { line: window.__anchorLine, offset: rect.top - top };
          }
          return { line: null, offset: 0 };
        },
        offsetOfLine(line) {
          const row = this.root().querySelector(`[data-line="${line}"]`);
          return row ? row.getBoundingClientRect().top - this.containerTop() : NaN;
        },
      };
      return true;
    })();
    """)

    try await harness.settle(seconds: 4)
    return harness
  }

  @discardableResult
  func evaluate(_ script: String) async throws -> [String: Any] {
    let result = try await webView.evaluateJavaScript(script)
    return result as? [String: Any] ?? [:]
  }

  func settle(seconds: Double = 2) async throws {
    try await Task.sleep(for: .seconds(seconds))
  }
}

@MainActor
private final class HarnessLoadObserver: NSObject, WKNavigationDelegate {
  private var continuation: CheckedContinuation<Void, Error>?

  func wait(for webView: WKWebView, loading html: String) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      self.continuation = continuation
      webView.navigationDelegate = self
      webView.loadHTMLString(html, baseURL: nil)
    }
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    continuation?.resume(); continuation = nil
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    continuation?.resume(throwing: error); continuation = nil
  }
}
