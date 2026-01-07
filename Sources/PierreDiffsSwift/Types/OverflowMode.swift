//
//  OverflowMode.swift
//  PierreDiffsSwift
//
//  Created by James Rochabrun on 1/6/26.
//

import Foundation

// MARK: - OverflowMode

public enum OverflowMode: String, CaseIterable, Identifiable, Sendable {
  case scroll
  case wrap

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .scroll:
      return "Scroll"
    case .wrap:
      return "Wrap"
    }
  }
}
