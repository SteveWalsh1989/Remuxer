import Foundation
import UniformTypeIdentifiers

enum SupportedInputFile {
  static let fileExtensions: Set<String> = ["mkv", "mp4"]

  static var allowedContentTypes: [UTType] {
    [UTType(filenameExtension: "mkv") ?? .movie, .mpeg4Movie]
  }

  static func isSupported(_ url: URL) -> Bool {
    fileExtensions.contains(url.pathExtension.lowercased())
  }
}
