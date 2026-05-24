import Foundation

protocol OutputPreparing {
  func prepareOutput(for output: PlannedOutput) throws
}

struct OutputPreparer: OutputPreparing {
  let fileManager: FileManager

  init(fileManager: FileManager = .default) {
    self.fileManager = fileManager
  }

  func prepareOutput(for output: PlannedOutput) throws {
    let outputDirectories = Set(
      ([output.videoURL] + output.sidecarURLs)
        .map { $0.deletingLastPathComponent().standardizedFileURL }
    )

    for directoryURL in outputDirectories {
      try fileManager.createDirectory(
        at: directoryURL,
        withIntermediateDirectories: true,
        attributes: nil
      )
    }
  }
}
