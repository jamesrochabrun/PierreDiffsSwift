//
//  LineClickPosition.swift
//  PierreDiffsSwift
//
//  Created by Assistant on 1/16/26.
//

import Foundation

/// Data about a clicked line position in the diff view.
/// Used for positioning floating UI elements below clicked lines.
public struct LineClickPosition: Sendable {
  /// The line number that was clicked
  public let lineNumber: Int

  /// Which side of the diff was clicked ("left", "right", or "unified")
  public let side: String

  /// Y position of the line's bottom edge in WebView coordinates
  public let lineY: CGFloat

  /// Height of the line element in pixels
  public let lineHeight: CGFloat

  public init(lineNumber: Int, side: String, lineY: CGFloat, lineHeight: CGFloat) {
    self.lineNumber = lineNumber
    self.side = side
    self.lineY = lineY
    self.lineHeight = lineHeight
  }
}
