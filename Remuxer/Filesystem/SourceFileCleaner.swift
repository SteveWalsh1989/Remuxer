import Foundation

protocol SourceFileCleaning {
  func removeSourceFile(at url: URL) throws
}

struct SourceFileCleaner: SourceFileCleaning {
  let fileManager: FileManager

  init(fileManager: FileManager = .default) {
    self.fileManager = fileManager
  }

  func removeSourceFile(at url: URL) throws {
    do {
      try fileManager.removeItem(at: url)
    } catch {
      throw SourceFileDeletionError.removeFailed(url, error.localizedDescription)
    }
  }
}

enum SourceFileDeletionError: LocalizedError {
  case removeFailed(URL, String)

  var errorDescription: String? {
    switch self {
    case .removeFailed(let url, let reason):
      "Conversion completed, but Remuxer could not remove the original file "
        + "\"\(url.lastPathComponent)\". \(reason)"
    }
  }
}
