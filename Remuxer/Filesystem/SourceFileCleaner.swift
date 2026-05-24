import Foundation

protocol SourceFileCleaning {
  func moveSourceFileToTrash(at url: URL) throws
}

struct SourceFileCleaner: SourceFileCleaning {
  let fileManager: FileManager

  init(fileManager: FileManager = .default) {
    self.fileManager = fileManager
  }

  func moveSourceFileToTrash(at url: URL) throws {
    do {
      try fileManager.trashItem(at: url, resultingItemURL: nil)
    } catch {
      throw SourceFileCleanupError.trashFailed(url, error.localizedDescription)
    }
  }
}

enum SourceFileCleanupError: LocalizedError {
  case trashFailed(URL, String)

  var errorDescription: String? {
    switch self {
    case .trashFailed(let url, let reason):
      "Conversion completed, but Remuxer could not move the original file "
        + "\"\(url.lastPathComponent)\" to Trash. \(reason)"
    }
  }
}
