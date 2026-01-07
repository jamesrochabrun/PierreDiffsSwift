//
//  PierreDiffInput.swift
//  PierreDiffsSwift
//
//  Created by James Rochabrun on 1/6/26.
//

import Foundation

/// Input data structure for rendering diffs with @pierre/diffs.
/// This matches the JavaScript library's expected format.
public struct PierreDiffInput: Codable, Sendable {

  /// Represents a file's contents for diff comparison.
  public struct FileContents: Codable, Sendable {
    /// The filename (used for display and language detection)
    public let name: String

    /// The file's text content
    public let contents: String

    /// Optional language override for syntax highlighting.
    /// If nil, language is auto-detected from filename.
    public let lang: String?

    public init(name: String, contents: String, lang: String? = nil) {
      self.name = name
      self.contents = contents
      self.lang = lang
    }
  }

  /// Configuration options for the diff renderer.
  public struct Options: Codable, Sendable {
    /// Theme configuration for dark/light modes
    public let theme: ThemeConfig

    /// Diff view style: "split" or "unified"
    public let diffStyle: String

    /// Overflow mode: "scroll" or "wrap"
    public let overflow: String

    /// Enable click-to-select on line numbers
    public let enableLineSelection: Bool

    public init(theme: ThemeConfig, diffStyle: String, overflow: String, enableLineSelection: Bool) {
      self.theme = theme
      self.diffStyle = diffStyle
      self.overflow = overflow
      self.enableLineSelection = enableLineSelection
    }
  }

  /// Theme configuration supporting dark and light modes.
  public struct ThemeConfig: Codable, Sendable {
    /// Theme name for dark mode (e.g., "pierre-dark")
    public let dark: String

    /// Theme name for light mode (e.g., "pierre-light")
    public let light: String

    public init(dark: String, light: String) {
      self.dark = dark
      self.light = light
    }
  }

  /// The original file (before changes)
  public let oldFile: FileContents

  /// The new file (after changes)
  public let newFile: FileContents

  /// Rendering options
  public let options: Options

  public init(oldFile: FileContents, newFile: FileContents, options: Options) {
    self.oldFile = oldFile
    self.newFile = newFile
    self.options = options
  }
}

// MARK: - Convenience Initializers

extension PierreDiffInput {

  /// Creates a PierreDiffInput from a DiffResult.
  ///
  /// - Parameters:
  ///   - diffResult: The diff result containing original and updated content
  ///   - diffStyle: The style to use for rendering
  ///   - overflowMode: The overflow mode (scroll or wrap)
  /// - Returns: A configured PierreDiffInput
  public static func from(
    diffResult: DiffResult,
    diffStyle: DiffStyle = .split,
    overflowMode: OverflowMode = .scroll
  ) -> PierreDiffInput {
    PierreDiffInput(
      oldFile: FileContents(
        name: diffResult.fileName,
        contents: diffResult.original,
        lang: nil
      ),
      newFile: FileContents(
        name: diffResult.fileName,
        contents: diffResult.updated,
        lang: nil
      ),
      options: Options(
        theme: ThemeConfig(
          dark: "pierre-dark",
          light: "pierre-light"
        ),
        diffStyle: diffStyle.rawValue,
        overflow: overflowMode.rawValue,
        enableLineSelection: true
      )
    )
  }
}
