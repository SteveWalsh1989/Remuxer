import Foundation

struct FFmpegToolchain: Equatable {
  let ffmpegURL: URL
  let ffprobeURL: URL
}

protocol ToolLocating {
  func locateToolchain() throws -> FFmpegToolchain
}

enum ToolchainError: LocalizedError, Equatable {
  case missingFFmpeg
  case missingFFprobe

  var errorDescription: String? {
    switch self {
    case .missingFFmpeg:
      [
        "Remuxer is missing its bundled conversion engine.",
        "The app bundle does not contain ffmpeg.",
        "Use a complete Remuxer build.",
      ].joined(separator: " ")
    case .missingFFprobe:
      [
        "Remuxer is missing its bundled media analyzer.",
        "The app bundle does not contain ffprobe.",
        "Use a complete Remuxer build.",
      ].joined(separator: " ")
    }
  }
}

struct ProcessToolLocator: ToolLocating {
  static var defaultBundledSearchDirectories: [URL] {
    guard let resourceURL = Bundle.main.resourceURL else {
      return []
    }

    return [
      resourceURL.appendingPathComponent("FFmpeg/bin")
    ]
  }

  static var defaultDeveloperSearchDirectories: [URL] {
    guard let runtimePath = ProcessInfo.processInfo.environment["REMUXER_FFMPEG_BIN_DIR"],
      runtimePath.isEmpty == false
    else {
      return []
    }

    return [URL(fileURLWithPath: runtimePath)]
  }

  private let bundledSearchDirectories: [URL]
  private let developerSearchDirectories: [URL]

  init(
    bundledSearchDirectories: [URL] = Self.defaultBundledSearchDirectories,
    developerSearchDirectories: [URL] = Self.defaultDeveloperSearchDirectories
  ) {
    self.bundledSearchDirectories = bundledSearchDirectories
    self.developerSearchDirectories = developerSearchDirectories
  }

  func locateToolchain() throws -> FFmpegToolchain {
    guard let ffmpegURL = locateExecutable(named: "ffmpeg") else {
      throw ToolchainError.missingFFmpeg
    }

    guard let ffprobeURL = locateExecutable(named: "ffprobe") else {
      throw ToolchainError.missingFFprobe
    }

    return FFmpegToolchain(ffmpegURL: ffmpegURL, ffprobeURL: ffprobeURL)
  }

  private func locateExecutable(named executableName: String) -> URL? {
    effectiveSearchDirectories
      .map { $0.appendingPathComponent(executableName) }
      .first { FileManager.default.isExecutableFile(atPath: $0.path) }
  }

  private var effectiveSearchDirectories: [URL] {
    var directories = bundledSearchDirectories
    directories.append(contentsOf: developerSearchDirectories)
    return directories.uniquedByStandardizedFileURL()
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
