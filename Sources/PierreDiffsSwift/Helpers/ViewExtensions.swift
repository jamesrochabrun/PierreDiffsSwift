//
//  ViewExtensions.swift
//  PierreDiffsSwift
//

import SwiftUI

extension View {
  public func clickThrough() -> some View {
    #if os(macOS)
    return self.allowsHitTesting(true)
    #else
    return self
    #endif
  }
}

extension View {

  public func roundBorder(cornerRadius: CGFloat) -> some View {
    self.overlay(
      RoundedRectangle(cornerRadius: cornerRadius)
        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
    )
    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
  }
}
