//
//  FileContent.swift
//  PierreDiffsSwift
//
//  Created by James Rochabrun on 9/3/25.
//

import Foundation

// MARK: - FileContent

public struct FileContent: Codable, Sendable {
  enum CodingKeys: String, CodingKey {
    case content
    case filePath = "file_path"
  }

  public let content: String
  public let filePath: String

  public init(content: String, filePath: String) {
    self.content = content
    self.filePath = filePath
  }
}

extension FileContent {

  public static func from(jsonData: Data) throws -> FileContent {
    let decoder = JSONDecoder()
    return try decoder.decode(FileContent.self, from: jsonData)
  }

  public static func from(jsonString: String) throws -> FileContent {
    guard let data = jsonString.data(using: .utf8) else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: [],
          debugDescription: "Unable to convert string to data"
        )
      )
    }
    return try from(jsonData: data)
  }
}
