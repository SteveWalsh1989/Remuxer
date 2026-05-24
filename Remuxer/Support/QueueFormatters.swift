import Foundation

enum QueueFormatters {
  static func percentage(_ value: Double) -> String {
    let percent = min(max(value, 0), 1) * 100
    return "\(Int(percent.rounded()))%"
  }

  static func path(_ url: URL?) -> String {
    guard let url else {
      return "None"
    }

    return url.path
  }
}
