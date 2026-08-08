# Changelog

All notable changes to PierreDiffsSwift are documented here.

## Unreleased

### Fixed

- Shared the main bundle's Shiki TextMate runtime with the lazy editor bundle so syntax-highlighted edits update the rendered document instead of failing after the model changes.

## 1.3.0 - 2026-08-08

### Added

- Added opt-in in-place editing for the new-file side of `PierreDiffView`.
- Added `PierreDiffEditorOptions` for undo history, bracket matching, auto-surround, custom macOS key bindings, rounded selections, and selection-action buttons.
- Added declarative severity markers with hover messages.
- Added `PierreDiffEditorController` for undo, redo, focus, blur, programmatic text edits, selections, and marker updates.
- Added controlled edit callbacks carrying complete updated content, normalized edits, and structurally shifted annotations.
- Added editor focus, blur, selection-action, and error callbacks.
- Added a separate lazy editor bundle so read-only views retain their existing loading cost.

### Changed

- Bumped the bundled `@pierre/diffs` dependency from `1.2.7` to `1.3.5`.
- Pinned the compatible Shiki toolchain to 4.4.1 for reproducible editor bundle generation.
- Updated the JavaScript bridge to preserve editor content and undo history when SwiftUI echoes controlled changes.

### Compatibility

- Read-only rendering continues to support macOS 14.0+.
- Edit mode requires WebKit/Safari 17.5+, available with macOS 14.5+.
- Upstream edit mode remains experimental in `@pierre/diffs` 1.3.x.

## 1.2.0 - 2026-06-04

### Added

- Added `PierreDiffRenderOptions` for low-risk @pierre/diffs render controls:
  - `theme`
  - `diffIndicators`
  - `hunkSeparators`
  - `lineDiffType`
  - `disableLineNumbers`
  - `disableFileHeader`
  - `disableBackground`
  - `expandUnchanged`
  - `collapsedContextThreshold`
  - `maxLineDiffLength`
  - `expansionLineCount`
  - `tokenizeMaxLength`
  - `tokenizeMaxLineLength`
  - `stickyHeader`
- Added public option enums: `DiffIndicatorStyle`, `LineDiffType`, and `HunkSeparatorStyle`.
- Added `PierreDiffTheme.pierre` and `PierreDiffTheme.pierreSoft`.
- Added upstream integration notes for agents in `docs/upstream-pierre-diffs.md`.

### Changed

- Bumped the bundled `@pierre/diffs` dependency from `1.1.12` to `1.2.7`.
- Rebuilt `Sources/PierreDiffsSwift/Resources/pierre-diffs-bundle.js`.
- Updated README and agent guidance for the new render options.

### Fixed

- Preserved the WebView scroll position when inline annotations are added, edited, or removed.
