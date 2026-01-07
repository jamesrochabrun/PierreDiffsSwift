//
//  AnimatedCopyButton.swift
//  PierreDiffsSwift
//

import SwiftUI

public struct AnimatedCopyButton: View {
  let textToCopy: String
  let title: String

  @State private var didCopy = false

  public init(textToCopy: String, title: String) {
    self.textToCopy = textToCopy
    self.title = title
  }

  public var body: some View {
    Button(action: {
#if os(iOS)
      UIPasteboard.general.string = textToCopy
#elseif os(macOS)
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(textToCopy, forType: .string)
#endif

      withAnimation(.easeInOut(duration: 0.2)) {
        didCopy = true
      }

      Task {
        try await Task.sleep(for: .seconds(2))
        await MainActor.run {
          withAnimation(.easeInOut(duration: 0.2)) {
            didCopy = false
          }
        }
      }
    }) {
      HStack {
        Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
        Text(didCopy ? "Copied!" : title)
      }
      .font(.caption)
    }
  }
}
