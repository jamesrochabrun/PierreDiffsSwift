//
//  DiffStateManager.swift
//  PierreDiffsSwift
//
//  Created by James Rochabrun on 9/3/25.
//

import Foundation
import SwiftUI

// MARK: - DiffStateManager

@Observable
public final class DiffStateManager: @unchecked Sendable {

  // MARK: Lifecycle

  public init() {}

  // MARK: Public

  public var stateCount: Int {
    states.count
  }

  /// Get state for a message
  public func getState(for messageID: UUID) -> DiffState {
    states[messageID] ?? .empty
  }

  @MainActor
  public func process(diffs: [DiffResult], for messageID: UUID) async {
    guard !diffs.isEmpty, let firstResult = diffs.first else {
      return
    }

    // Skip if we already have the same content
    if
      let existingState = states[messageID],
      existingState.diffResult.original == firstResult.original,
      existingState.diffResult.updated == firstResult.updated
    {
      return
    }

    // Store the DiffResult - @pierre/diffs handles all rendering
    states[messageID] = DiffState(diffResult: firstResult)
  }

  public func removeState(for messageID: UUID) {
    states.removeValue(forKey: messageID)
  }

  public func clearAllStates() {
    states.removeAll()
  }

  // MARK: Private

  private var states: [UUID: DiffState] = [:]
}
