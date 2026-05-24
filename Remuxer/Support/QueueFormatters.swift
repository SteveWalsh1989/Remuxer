import Foundation

enum QueueFormatters {
  static func percentage(_ value: Double) -> String {
    let percent = min(max(value, 0), 1) * 100
    return "\(Int(percent.rounded()))%"
  }

  static func duration(_ seconds: TimeInterval) -> String {
    let totalSeconds = max(0, Int(seconds.rounded()))
    let hours = totalSeconds / 3_600
    let minutes = (totalSeconds % 3_600) / 60
    let seconds = totalSeconds % 60

    if hours > 0 {
      return "\(hours)h \(minutes)m"
    }

    if minutes > 0 {
      return "\(minutes)m \(seconds)s"
    }

    return "\(seconds)s"
  }

  static func path(_ url: URL?) -> String {
    guard let url else {
      return "None"
    }

    return url.path
  }
}
