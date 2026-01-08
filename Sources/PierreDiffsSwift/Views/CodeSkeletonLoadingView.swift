//
//  CodeSkeletonLoadingView.swift
//  PierreDiffsSwift
//
//  Created on 1/7/26.
//

import SwiftUI

/// A beautiful skeleton loading view that mimics code structure with shimmering lines.
struct CodeSkeletonLoadingView: View {

  // MARK: - Properties

  @State private var isAnimating = false
  @Environment(\.colorScheme) private var colorScheme

  /// Base line pattern: (indent level, width percentage)
  private let linePattern: [(indent: Int, width: CGFloat)] = [
    (0, 0.6),   // function declaration
    (1, 0.8),   // longer line
    (1, 0.4),   // short line
    (1, 0.7),   // medium line
    (2, 0.5),   // nested indented
    (2, 0.65),  // nested indented
    (1, 0.3),   // short return
    (0, 0.2),   // closing brace
  ]

  /// All lines - repeat pattern to fill height
  private var allLines: [(indent: Int, width: CGFloat)] {
    Array(repeating: linePattern, count: 3).flatMap { $0 }
  }

  private var baseColor: Color {
    colorScheme == .dark
      ? Color.white.opacity(0.08)
      : Color.black.opacity(0.06)
  }

  private var shimmerColor: Color {
    colorScheme == .dark
      ? Color.white.opacity(0.15)
      : Color.white.opacity(0.9)
  }

  // MARK: - Body

  var body: some View {
    GeometryReader { geo in
      VStack(alignment: .leading, spacing: 8) {
        ForEach(Array(allLines.enumerated()), id: \.offset) { _, line in
          skeletonRow(
            indent: line.indent,
            widthFraction: line.width,
            availableWidth: geo.size.width
          )
        }
      }
      .padding(.vertical, 16)
    }
    .frame(minHeight: 500)
    .onAppear {
      withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) {
        isAnimating = true
      }
    }
  }

  // MARK: - Private

  private func skeletonRow(indent: Int, widthFraction: CGFloat, availableWidth: CGFloat) -> some View {
    let rowWidth = availableWidth * widthFraction

    return HStack(spacing: 0) {
      // Indentation
      if indent > 0 {
        Color.clear
          .frame(width: CGFloat(indent) * 20)
      }

      // Skeleton bar with shimmer
      RoundedRectangle(cornerRadius: 4)
        .fill(baseColor)
        .frame(width: rowWidth, height: 14)
        .overlay(
          shimmerOverlay(width: rowWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))

      Spacer()
    }
    .frame(height: 14)
  }

  private func shimmerOverlay(width: CGFloat) -> some View {
    Rectangle()
      .fill(
        LinearGradient(
          colors: [.clear, shimmerColor, .clear],
          startPoint: .leading,
          endPoint: .trailing
        )
      )
      .frame(width: 100)
      .offset(x: isAnimating ? width / 2 + 50 : -width / 2 - 50)
  }
}
