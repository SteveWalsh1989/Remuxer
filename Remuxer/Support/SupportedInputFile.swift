import Foundation
import UniformTypeIdentifiers

enum SupportedInputFile {
  static let fileExtensions: Set<String> = ["mkv"]

  static var allowedContentTypes: [UTType] {
    [UTType(filenameExtension: "mkv") ?? .movie]
  }

  static func isSupported(_ url: URL) -> Bool {
    fileExtensions.contains(url.pathExtension.lowercased())
  }
}
