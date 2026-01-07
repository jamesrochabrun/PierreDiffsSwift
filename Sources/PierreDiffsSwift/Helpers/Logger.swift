//
//  Logger.swift
//  PierreDiffsSwift
//
//  Created by James Rochabrun on 1/7/26.
//

import Foundation
import os.log

/// Internal logger for PierreDiffsSwift
enum DiffLogger {
  private static let logger = Logger(subsystem: "com.pierreDiffsSwift", category: "Diffs")

  static func info(_ message: String) {
    logger.info("\(message)")
  }

  static func error(_ message: String) {
    logger.error("\(message)")
  }

  static func debug(_ message: String) {
    logger.debug("\(message)")
  }

  static func warning(_ message: String) {
    logger.warning("\(message)")
  }
}
