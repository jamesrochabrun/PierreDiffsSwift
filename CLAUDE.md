# PierreDiffsSwift

## What This Project Is

A Swift package that wraps the `@pierre/diffs` JavaScript library (v1.3.5) to render and edit syntax-highlighted code diffs in macOS apps via WKWebView. It provides SwiftUI views, line interaction callbacks, inline annotations, and an opt-in editor.

## Architecture

```
PierreDiffView (SwiftUI NSViewRepresentable)
  ├── WKWebView
  │     ├── DiffHTMLTemplate (HTML + CSS)
  │     ├── pierre-diffs-bundle.js (read-only @pierre/diffs + bridge)
  │     └── pierre-diffs-edit-bundle.js (lazy @pierre/diffs/edit bundle)
  ├── DiffWebViewCoordinator (WKNavigationDelegate + WKScriptMessageHandler)
  │     ├── JS → Swift messaging via webkit.messageHandlers.diffBridge
  │     └── Swift → JS via evaluateJavaScript / base64-encoded callJavaScript
  └── Change detection in updateNSView (content, style, overflow, render options, theme, annotations)
```

### Key Files

| File | Purpose |
|------|---------|
| `Sources/.../WebView/PierreDiffView.swift` | Main NSViewRepresentable — all public API surface |
| `Sources/.../WebView/DiffWebViewCoordinator.swift` | WKWebView delegate, JS bridge, event handling |
| `Sources/.../WebView/DiffHTMLTemplate.swift` | HTML generation with embedded CSS and JS bundle |
| `Sources/.../WebView/DiffWebViewEvent.swift` | Enum of all events from JS → Swift |
| `Sources/.../Models/DiffAnnotation.swift` | `DiffAnnotation`, `AnnotationMetadata`, `AnnotationSide` |
| `Sources/.../Models/PierreDiffInput.swift` | Codable input sent to JS `renderDiff()` |
| `Sources/.../Types/PierreDiffRenderOptions.swift` | Public renderer option types passed through to `FileDiff` |
| `Sources/.../Types/PierreDiffEditorOptions.swift` | Public editor behavior and selection-action configuration |
| `Sources/.../State/PierreDiffEditorController.swift` | Reactive state and imperative editor commands |
| `Sources/.../Models/LineClickPosition.swift` | Position data for line click callbacks |
| `Sources/.../Models/LineSelectionRange.swift` | Range data for multi-line selection callbacks |
| `scripts/src/diff-entry.js` | JS entry point — bridge API, annotation DOM, events |
| `scripts/bundle.js` | esbuild config |
| `scripts/src/edit-entry.js` | Separate lazy editor bundle entry point |
| `scripts/package.json` | npm deps (`@pierre/diffs` 1.3.5 and compatible Shiki packages 4.4.1) |
| `CHANGELOG.md` | Wrapper release notes |
| `docs/upstream-pierre-diffs.md` | Upstream docs/version checklist for agents |

### Data Flow

**Rendering**: Swift → `PierreDiffInput` (Codable) → base64 encode → JS `window.pierreBridge.renderDiff(input)` → `@pierre/diffs` FileDiff renders DOM

**Events**: JS `postToSwift(type, payload)` → `webkit.messageHandlers.diffBridge.postMessage(...)` → `WKScriptMessageHandler` → `DiffWebViewEvent` enum → `handleMessage()` → callbacks

**Annotations**: Swift passes `[DiffAnnotation]` → encoded to JSON → JS `setLineAnnotations()` → `@pierre/diffs` calls `renderAnnotation(annotation)` → `createAnnotationDOM()` builds HTML element

**Editing**: Swift enables edit mode → coordinator evaluates the lazy editor bundle once → JS attaches `Editor` to the existing `FileDiff` → complete content, normalized edits, and shifted annotations flow back through `PierreDiffEditChange`

### Change Detection

`updateNSView` tracks previous values via coordinator properties (`lastOldContent`, `lastDiffStyle`, `lastRenderOptions`, `lastAnnotations`, editor configuration, markers, etc.) and only calls the relevant JS method when a specific property changes. Content and render option changes trigger full re-render; style/theme/overflow/annotation/editor changes use targeted update methods. Editor-originated controlled echoes are absorbed without replacing the DOM or undo history.

Consumers must keep `PierreDiffView`'s SwiftUI identity stable while editing and saving. Do not key `.id(...)` from edited content or rotate a document identity for a save echo; dismantling the view recreates the WebView and necessarily resets scroll, caret, and undo state. Identity changes are appropriate only when switching documents.

## Upstream Docs

Before exposing more `@pierre/diffs` APIs, read `docs/upstream-pierre-diffs.md`, then verify the pinned package's local declarations under `scripts/node_modules/@pierre/diffs/dist/`. Cross-check upstream docs and releases, but keep wrapper behavior aligned to the pinned version in `scripts/package.json`.

Current low-risk pass-through options live in `PierreDiffRenderOptions`: theme pair, diff indicators, hunk separator style, line diff type, line/header/background visibility, unchanged-hunk expansion, large-line diff limits, tokenization limits, and sticky headers. Keep defaults backward-compatible.

## Build Commands

```bash
# Rebuild read-only and lazy edit JS bundles
cd scripts && npm ci && npm run build

# Build Swift package
swift build

# Run tests
swift test
```

## Conventions

- Swift 6.0 strict concurrency — coordinator is `@MainActor`
- All public types are `Sendable`
- JS communication uses base64-encoded JSON to handle special characters safely
- CSS is theme-aware via `@media (prefers-color-scheme: dark)`
- Position callbacks use `NSEvent.mouseLocation` converted to WebView-local coordinates (top-left origin, matches SwiftUI)
- Edit mode is experimental and requires macOS 14.5+ (WebKit/Safari 17.5+); read-only rendering retains macOS 14.0+
- Keep `shiki`, `@shikijs/themes`, and `@shikijs/transformers` pinned to 4.4.1 unless an upstream update is verified; the Shiki 3.x tree lacks theme modules referenced by `@pierre/diffs` 1.3.5

## Annotation System

Annotations are **stateless from the library's perspective**. `PierreDiffView` renders whatever `[DiffAnnotation]` array it receives and fires callbacks on interaction. The consumer owns the state.

### Events from annotations:
- `onAnnotationClick(id, side, lineNumber, localPoint)` — user clicked annotation body
- `onAnnotationDelete(id, side, lineNumber)` — user clicked the X delete button

### Dynamic updates:
- Changing the `annotations` array triggers `updateNSView` → `coordinator.setAnnotations()` (no full re-render)
- Setting annotations to `nil` or `[]` calls `coordinator.removeAnnotations()`
