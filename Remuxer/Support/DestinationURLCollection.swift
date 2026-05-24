import Foundation

extension Array where Element == URL {
  mutating func removeDestination(_ url: URL) {
    let normalizedURL = url.standardizedFileURL
    removeAll { $0.standardizedFileURL == normalizedURL }
  }

  func containsDestination(_ url: URL) -> Bool {
    let normalizedURL = url.standardizedFileURL
    return contains { $0.standardizedFileURL == normalizedURL }
  }
}
