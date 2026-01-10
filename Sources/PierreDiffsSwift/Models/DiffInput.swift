//
//  DiffInput.swift
//  PierreDiffsSwift
//
//  Created by James Rochabrun on 1/9/26.
//

import Foundation

/// Input types for DiffEditsView
public enum DiffInput {
  /// Tool-based input from Claude's edit/write tools
  case tool(
    messageID: UUID,
    editTool: EditTool,
    toolParameters: [String: String],
    projectPath: String?,
    diffStore: DiffStateManager?,
    diffLifecycleState: DiffLifecycleState?
  )

  /// Direct content input (old/new strings)
  case direct(
    oldContent: String,
    newContent: String,
    fileName: String
  )
}
