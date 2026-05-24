import Foundation

protocol SecurityScopedResourceAccessing {
  func access<T>(
    urls: [URL],
    operation: () async throws -> T
  ) async throws -> T
}

struct SecurityScopedResourceAccess: SecurityScopedResourceAccessing {
  func access<T>(
    urls: [URL],
    operation: () async throws -> T
  ) async throws -> T {
    let uniqueURLs = urls.uniquedByStandardizedFileURL()
    let accessedURLs = uniqueURLs.filter { $0.startAccessingSecurityScopedResource() }
    defer {
      for url in accessedURLs {
        url.stopAccessingSecurityScopedResource()
      }
    }

    return try await operation()
  }
}

extension Array where Element == URL {
  fileprivate func uniquedByStandardizedFileURL() -> [URL] {
    var seenURLs = Set<URL>()
    var result: [URL] = []

    for url in self {
      let standardizedURL = url.standardizedFileURL
      guard seenURLs.contains(standardizedURL) == false else {
        continue
      }

      seenURLs.insert(standardizedURL)
      result.append(url)
    }

    return result
  }
}
