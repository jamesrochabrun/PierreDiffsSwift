//
//  DiffWebViewEvent.swift
//  PierreDiffsSwift
//
//  Created by James Rochabrun on 1/6/26.
//

import Foundation

/// Events sent from the JavaScript diff renderer to Swift.
enum DiffWebViewEvent {
  /// The JavaScript bridge is ready to receive commands
  case bridgeReady

  /// The diff has been rendered and is ready for interaction
  case ready

  /// A line was clicked (includes position for UI overlay positioning)
  case lineClicked(lineNumber: Int, side: String, lineY: CGFloat, lineHeight: CGFloat)

  /// Text selection changed
  case selectionChanged(startLine: Int, endLine: Int, side: String)

  /// System theme changed
  case systemThemeChanged(isDark: Bool)

  /// An annotation was clicked
  case annotationClicked(id: String, side: String, lineNumber: Int)

  /// An annotation delete was requested
  case annotationDeleteRequested(id: String, side: String, lineNumber: Int)

  /// The editable new-file document changed.
  case editorChanged(PierreDiffEditChange)

  /// Editor attachment, history, or content state changed.
  case editorStateChanged(
    content: String,
    isAttached: Bool,
    isFocused: Bool?,
    canUndo: Bool,
    canRedo: Bool
  )

  /// The editor gained focus.
  case editorFocused

  /// The editor lost focus.
  case editorBlurred

  /// A configured selection action was chosen.
  case editorSelectionAction(PierreDiffSelectionActionEvent)

  /// The experimental editor reported an error.
  case editorError(message: String)

  /// An error occurred in the JavaScript layer
  case error(message: String)
}
