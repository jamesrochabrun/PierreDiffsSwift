//
//  FileEdit.swift
//  PierreDiffsSwift
//
//  Created by James Rochabrun on 9/3/25.
//

import Foundation

// MARK: - FileEdit

public struct FileEdit: Codable, Sendable {
  enum CodingKeys: String, CodingKey {
    case filePath = "file_path"
    case edits
    case newString = "new_string"
    case oldString = "old_string"
    case replaceAll = "replace_all"
  }

  public let filePath: String
  public let edits: [Edit]?
  public let newString: String?
  public let oldString: String?
  public let replaceAll: Bool?

  public var allEdits: [Edit] {
    if let edits {
      return edits
    } else if let newString, let oldString {
      return [Edit(newString: newString, oldString: oldString, replaceAll: replaceAll ?? false)]
    }
    return []
  }

  public init(
    filePath: String,
    edits: [Edit]? = nil,
    newString: String? = nil,
    oldString: String? = nil,
    replaceAll: Bool? = nil
  ) {
    self.filePath = filePath
    self.edits = edits
    self.newString = newString
    self.oldString = oldString
    self.replaceAll = replaceAll
  }
}

// MARK: - Edit

public struct Edit: Codable, Sendable {

  public let newString: String
  public let oldString: String
  public let replaceAll: Bool

  enum CodingKeys: String, CodingKey {
    case newString = "new_string"
    case oldString = "old_string"
    case replaceAll = "replace_all"
  }

  public init(newString: String, oldString: String, replaceAll: Bool) {
    self.newString = newString
    self.oldString = oldString
    self.replaceAll = replaceAll
  }
}
