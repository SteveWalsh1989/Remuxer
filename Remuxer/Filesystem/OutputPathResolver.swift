import Foundation

protocol FileExistenceChecking {
  func fileExists(atPath path: String) -> Bool
}

extension FileManager: FileExistenceChecking {}

enum OutputPathError: LocalizedError, Equatable {
  case missingSelectedFolder
  case outputExists(URL)
  case invalidCustomFileName(String)

  var errorDescription: String? {
    switch self {
    case .missingSelectedFolder:
      "Choose an output folder before using the selected-folder destination."
    case .outputExists(let url):
      "Output already exists: \(url.lastPathComponent)"
    case .invalidCustomFileName(let name):
      "The output name \"\(name)\" is not a valid file name."
    }
  }
}

struct OutputPathResolver {
  let fileChecker: FileExistenceChecking

  init(fileChecker: FileExistenceChecking = FileManager.default) {
    self.fileChecker = fileChecker
  }

  func videoOutputURL(
    for sourceURL: URL,
    preset: ConversionPreset,
    options: OutputOptions,
    customOutputName: String? = nil
  ) throws -> URL {
    let folderURL = try outputFolderURL(for: sourceURL, options: options)
    let baseName = try outputBaseName(
      for: sourceURL,
      outputExtension: preset.outputExtension,
      customOutputName: customOutputName
    )
    let candidate =
      folderURL
      .appendingPathComponent(baseName)
      .appendingPathExtension(preset.outputExtension)

    return try resolveCollision(for: candidate, options: options)
  }

  func sidecarURL(
    for sourceURL: URL,
    stream: MediaStream,
    extension sidecarExtension: String,
    options: OutputOptions,
    reservedURLs: Set<URL> = [],
    customOutputName: String? = nil,
    videoOutputExtension: String? = nil
  ) throws -> URL {
    let folderURL = try outputFolderURL(for: sourceURL, options: options)
    let baseName = try outputBaseName(
      for: sourceURL,
      outputExtension: videoOutputExtension,
      customOutputName: customOutputName
    )
    let streamLabel = sidecarLabel(for: stream)
    let candidate =
      folderURL
      .appendingPathComponent("\(baseName).\(streamLabel)")
      .appendingPathExtension(sidecarExtension)

    return try resolveCollision(for: candidate, options: options, reservedURLs: reservedURLs)
  }

  private func outputFolderURL(for sourceURL: URL, options: OutputOptions) throws -> URL {
    switch options.locationMode {
    case .besideSource:
      sourceURL.deletingLastPathComponent()
    case .selectedFolder:
      if let selectedFolderURL = options.selectedFolderURL {
        selectedFolderURL
      } else {
        throw OutputPathError.missingSelectedFolder
      }
    case .perSourceFolder:
      try parentFolderURL(for: sourceURL, options: options)
        .appendingPathComponent(sourceURL.deletingPathExtension().lastPathComponent)
    }
  }

  private func parentFolderURL(for sourceURL: URL, options: OutputOptions) throws -> URL {
    if let selectedFolderURL = options.selectedFolderURL {
      return selectedFolderURL
    }

    return sourceURL.deletingLastPathComponent()
  }

  private func outputBaseName(
    for sourceURL: URL,
    outputExtension: String?,
    customOutputName: String?
  ) throws -> String {
    guard let customName = OutputName(customOutputName) else {
      return sourceURL.deletingPathExtension().lastPathComponent
    }

    let rawName = customName.value
    guard rawName.contains("/") == false, rawName != ".", rawName != ".." else {
      throw OutputPathError.invalidCustomFileName(rawName)
    }

    if let outputExtension,
      rawName.lowercased().hasSuffix(".\(outputExtension.lowercased())")
    {
      let extensionStart = rawName.index(rawName.endIndex, offsetBy: -outputExtension.count - 1)
      let baseName = String(rawName[..<extensionStart])
      guard baseName.isEmpty == false else {
        throw OutputPathError.invalidCustomFileName(rawName)
      }

      return baseName
    }

    return rawName
  }

  private func resolveCollision(
    for candidateURL: URL,
    options: OutputOptions,
    reservedURLs: Set<URL> = []
  ) throws -> URL {
    let normalizedCandidate = candidateURL.standardizedFileURL

    switch options.collisionResolution {
    case .replace:
      return candidateURL
    case .block:
      guard exists(normalizedCandidate, reservedURLs: reservedURLs) == false else {
        throw OutputPathError.outputExists(candidateURL)
      }

      return candidateURL
    case .autoRename:
      return autoRenamedURL(for: candidateURL, reservedURLs: reservedURLs)
    }
  }

  private func autoRenamedURL(for candidateURL: URL, reservedURLs: Set<URL>) -> URL {
    var attempt = candidateURL
    var suffix = 2

    while exists(attempt.standardizedFileURL, reservedURLs: reservedURLs) {
      let folderURL = candidateURL.deletingLastPathComponent()
      let baseName = candidateURL.deletingPathExtension().lastPathComponent
      let pathExtension = candidateURL.pathExtension
      attempt =
        folderURL
        .appendingPathComponent("\(baseName) \(suffix)")
        .appendingPathExtension(pathExtension)
      suffix += 1
    }

    return attempt
  }

  private func exists(_ url: URL, reservedURLs: Set<URL>) -> Bool {
    reservedURLs.contains(url.standardizedFileURL) || fileChecker.fileExists(atPath: url.path)
  }

  private func sidecarLabel(for stream: MediaStream) -> String {
    if let language = stream.language, language.isEmpty == false {
      return "\(stream.index).\(language)"
    }

    return "\(stream.index)"
  }
}
