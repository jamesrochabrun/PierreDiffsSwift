//
//  DiffLifecycleState.swift
//  PierreDiffsSwift
//
//  Created by James Rochabrun on 9/3/25.
//

import Foundation

// MARK: - DiffLifecycleState

public struct DiffLifecycleState: Codable, Equatable, Sendable {
  /// Set of diff group IDs that have been applied
  public var appliedDiffGroupIDs: Set<String>

  /// Set of diff group IDs that have been rejected
  public var rejectedDiffGroupIDs: Set<String>

  /// Timestamps when each diff was applied (keyed by group ID)
  public var appliedTimestamps: [String: Date]

  /// Timestamps when each diff was rejected (keyed by group ID)
  public var rejectedTimestamps: [String: Date]

  /// Last time this state was modified
  public var lastModified: Date

  public init(
    appliedDiffGroupIDs: Set<String> = [],
    rejectedDiffGroupIDs: Set<String> = [],
    appliedTimestamps: [String: Date] = [:],
    rejectedTimestamps: [String: Date] = [:],
    lastModified: Date = Date()
  ) {
    self.appliedDiffGroupIDs = appliedDiffGroupIDs
    self.rejectedDiffGroupIDs = rejectedDiffGroupIDs
    self.appliedTimestamps = appliedTimestamps
    self.rejectedTimestamps = rejectedTimestamps
    self.lastModified = lastModified
  }
}
