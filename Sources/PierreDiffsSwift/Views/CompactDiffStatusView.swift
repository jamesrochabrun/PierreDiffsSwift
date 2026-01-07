//
//  CompactDiffStatusView.swift
//  PierreDiffsSwift
//
//  Created on 11/06/25.
//

import SwiftUI

/// A compact view showing that changes have been reviewed
///
/// This view is used to replace full diff displays after a user has processed them,
/// significantly improving performance in long sessions. Users can tap to expand
/// and see the full diff in a modal if needed.
public struct CompactDiffStatusView: View {

  // MARK: - Properties

  public let fileName: String
  public let timestamp: Date?
  public let onTapToExpand: () -> Void

  private var icon: String {
    "checkmark.circle.fill"
  }

  private var label: String {
    "Changes Reviewed"
  }

  // MARK: - Initialization

  public init(
    fileName: String,
    timestamp: Date?,
    onTapToExpand: @escaping () -> Void
  ) {
    self.fileName = fileName
    self.timestamp = timestamp
    self.onTapToExpand = onTapToExpand
  }

  // MARK: - Body

  public var body: some View {
    HStack(spacing: 8) {
      // Status icon
      Image(systemName: icon)
        .foregroundColor(.green)
        .font(.system(size: 12))

      // File info
      VStack(alignment: .leading, spacing: 2) {
        Text(label)
          .font(.caption)
          .foregroundColor(.green)

        Text(fileName)
          .font(.caption2)
          .foregroundColor(.secondary)
          .lineLimit(1)
      }

      Spacer()
    }
    .padding(8)
    .background(
      RoundedRectangle(cornerRadius: 6)
        .fill(Color.secondary.opacity(0.05))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 6)
        .stroke(Color.green.opacity(0.2), lineWidth: 0.5)
    )
    .contentShape(Rectangle())
    .onTapGesture(perform: onTapToExpand)
  }
}
