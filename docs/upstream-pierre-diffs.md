# Upstream @pierre/diffs Notes

PierreDiffsSwift wraps a pinned bundled build of `@pierre/diffs`.

## Current Pin

- npm package: `@pierre/diffs`
- pinned version: `1.3.5`
- compatibility pins: `shiki`, `@shikijs/themes`, and `@shikijs/transformers` at `4.4.1`
- configured in: `scripts/package.json`
- bundled outputs: `Sources/PierreDiffsSwift/Resources/pierre-diffs-bundle.js` and `Sources/PierreDiffsSwift/Resources/pierre-diffs-edit-bundle.js`

## Before Integrating Upstream APIs

1. Read the pinned dependency version in `scripts/package.json`.
2. Run `cd scripts && npm install` if `scripts/node_modules` is missing.
3. Check the local type declarations for the pinned version:
   - `scripts/node_modules/@pierre/diffs/dist/components/FileDiff.d.ts`
   - `scripts/node_modules/@pierre/diffs/dist/components/CodeView.d.ts`
   - `scripts/node_modules/@pierre/diffs/dist/types.d.ts`
   - `scripts/node_modules/@pierre/diffs/dist/edit/index.d.ts`
   - `scripts/node_modules/@pierre/diffs/dist/editor/editor.d.ts`
4. Cross-check current upstream docs and releases:
   - https://diffs.com/docs
   - https://diffs.com/
   - https://github.com/pierrecomputer/pierre/releases
5. Prefer additive Swift wrapper APIs that preserve `PierreDiffView` defaults.
6. Rebuild both bundles with `cd scripts && npm ci && npm run build`.
7. Run `swift test`.

Do not assume upstream `latest` docs match the pinned bundled version. If the npm pin changes, update this file, `CHANGELOG.md`, `README.md`, `AGENTS.md`, and `CLAUDE.md`.

## Wrapper Scope

`PierreDiffView` wraps upstream `FileDiff`, not `CodeView`. Low-risk `FileDiff` options can be exposed through `PierreDiffRenderOptions`.

`CodeView` is a larger upstream API for multi-file virtualized review surfaces. Adding it should be treated as a new Swift view, such as `PierreCodeView` or `PierreMultiFileDiffView`, rather than an expansion of `PierreDiffView`.

## Edit Integration

`PierreDiffView` attaches the vanilla `Editor` from `@pierre/diffs/edit` to its existing `FileDiff`. Only the new-file side is editable; deleted lines remain read-only.

The edit entry point is built as `pierre-diffs-edit-bundle.js` and evaluated only after edit mode is first enabled. Keep it separate from `pierre-diffs-bundle.js` so read-only consumers do not load editor code.

Keep the Shiki 4.4.1 compatibility pins synchronized. Without explicit pins, npm can retain a compatible-by-range Shiki 3.x lock tree that does not export `ayu-light`, `ayu-mirage`, `horizon`, `horizon-bright`, or `night-owl-light`, all referenced by `@pierre/theming` 1.0.1 during bundling.

The consumer owns edited content and annotations. The bridge updates its live new-file reference before publishing `PierreDiffEditChange`, which prevents declarative marker/annotation updates from restoring stale content. SwiftUI echoes matching editor content and annotations are accepted without a full render so undo history remains intact.

Edit mode in upstream 1.3 is experimental. It requires Safari/WebKit 17.5+; PierreDiffsSwift keeps its macOS 14.0 read-only deployment floor and documents macOS 14.5+ for editing.
