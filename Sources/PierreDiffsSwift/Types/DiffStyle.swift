//
//  DiffStyle.swift
//  PierreDiffsSwift
//
//  Created by James Rochabrun on 1/6/26.
//

import Foundation

// MARK: - DiffStyle

public enum DiffStyle: String, CaseIterable, Identifiable, Sendable {
  case split
  case unified

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .split:
      return "Split"
    case .unified:
      return "Unified"
    }
  }
}
