import Foundation
import Testing
import WebKit
@testable import PierreDiffsSwift

/// The Swift → JavaScript bridge ships its payload as base64. Decoding it with
/// `atob` alone reads UTF-8 bytes as Latin-1, which garbles every non-ASCII
/// scalar; these tests pin the UTF-8-safe decode.
@MainActor
@Test func bridgeScriptDecodesPayloadAsUTF8() {
  let script = DiffWebViewCoordinator.bridgeScript(method: "renderDiff", base64Payload: "e30=")

  #expect(script.contains("new TextDecoder('utf-8')"))
  #expect(script.contains("Uint8Array.from"))
  #expect(script.contains("window.pierreBridge.renderDiff(input)"))
  // The raw `atob` output must never be handed to JSON.parse directly.
  #expect(!script.contains("JSON.parse(binary)"))
}

@MainActor
@Test func bridgeScriptRoundTripsNonASCIIThroughWebKit() async throws {
  let payload = ["subtitle": "Lines 90–93", "body": "café — naïve 👋 日本語"]
  let base64 = try JSONEncoder().encode(payload).base64EncodedString()

  let webView = WKWebView(frame: .zero)
  try await webView.loadHTML(
    "<html><body><script>window.pierreBridge = { renderDiff(input) { window.__received = input; } };</script></body></html>"
  )

  _ = try await webView.evaluateJavaScript(
    DiffWebViewCoordinator.bridgeScript(method: "renderDiff", base64Payload: base64)
  )

  let subtitle = try await webView.evaluateJavaScript("window.__received.subtitle") as? String
  let body = try await webView.evaluateJavaScript("window.__received.body") as? String

  #expect(subtitle == payload["subtitle"])
  #expect(body == payload["body"])
}

// MARK: - Helpers

@MainActor
private final class LoadObserver: NSObject, WKNavigationDelegate {
  private var continuation: CheckedContinuation<Void, Error>?

  func wait(for webView: WKWebView, loading html: String) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
      self.continuation = continuation
      webView.navigationDelegate = self
      webView.loadHTMLString(html, baseURL: nil)
    }
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    continuation?.resume()
    continuation = nil
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
    continuation?.resume(throwing: error)
    continuation = nil
  }
}

extension WKWebView {
  @MainActor
  fileprivate func loadHTML(_ html: String) async throws {
    let observer = LoadObserver()
    try await observer.wait(for: self, loading: html)
    // Keep the delegate alive for the duration of the load.
    withExtendedLifetime(observer) {}
  }
}
