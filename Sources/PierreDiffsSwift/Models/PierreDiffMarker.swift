import Foundation

/// A severity-aware marker rendered as an inline underline with a hover message.
public struct PierreDiffMarker: Codable, Sendable, Equatable {
  public var start: PierreDiffTextPosition
  public var end: PierreDiffTextPosition
  public var severity: PierreDiffMarkerSeverity
  public var message: String
  public var source: String?

  public init(
    start: PierreDiffTextPosition,
    end: PierreDiffTextPosition,
    severity: PierreDiffMarkerSeverity,
    message: String,
    source: String? = nil
  ) {
    self.start = start
    self.end = end
    self.severity = severity
    self.message = message
    self.source = source
  }
}
