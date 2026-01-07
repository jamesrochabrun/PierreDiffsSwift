//
//  DiffResult.swift
//  PierreDiffsSwift
//
//  Created by James Rochabrun on 9/3/25.
//

import Foundation

// MARK: - DiffResult

public struct DiffResult: Equatable, Codable, Sendable {

  // MARK: Lifecycle

  public init(
    filePath: String,
    fileName: String,
    original: String,
    updated: String,
    isInitial: Bool = false
  ) {
    self.filePath = filePath
    self.fileName = fileName
    self.original = original
    self.updated = updated
    self.isInitial = isInitial
  }

  // MARK: Public

  public var filePath: String
  public var fileName: String
  public var original: String
  public var updated: String
  public var isInitial: Bool
}

extension DiffResult {

  public static let initial = DiffResult(filePath: "", fileName: "", original: "", updated: "", isInitial: true)
}
